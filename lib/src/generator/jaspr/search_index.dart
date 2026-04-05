// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:analyzer/file_system/file_system.dart';
import 'package:dartdoc_modern/src/generator/core/path_utils.dart'
    show sanitizeAnchor;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// Builds a static search index consumed by the generated Jaspr scaffold.
///
/// The index is intentionally backend-side and file-based:
/// - generation stays independent from frontend runtime implementation details
/// - search can be verified from generated artifacts
/// - the scaffold only needs to fetch one JSON file
class JasprSearchIndexBuilder {
  const JasprSearchIndexBuilder({
    required this.resourceProvider,
    required this.outputPath,
  });

  final ResourceProvider resourceProvider;
  final String outputPath;

  SearchIndexOutput build(Iterable<String> relativePaths) {
    final markdownPaths = relativePaths
        .where(
          (path) => path.startsWith('content/') && path.endsWith('.md'),
        )
        .toList()
      ..sort();

    final pageEntries = <SearchIndexEntry>[];
    final sectionEntries = <SectionIndexEntry>[];
    for (final relativePath in markdownPaths) {
      final fullPath = p.normalize(p.join(outputPath, relativePath));
      final file = resourceProvider.getFile(fullPath);
      if (!file.exists) continue;

      final entries = buildEntriesForPage(
        relativePath: relativePath,
        markdown: file.readAsStringSync(),
      );
      if (entries.isEmpty) continue;
      final pageIndex = pageEntries.length;
      pageEntries.add(entries.first);
      sectionEntries.addAll(
        entries.skip(1).map(
              (entry) => SectionIndexEntry.fromPageEntry(
                pageIndex: pageIndex,
                pageUrl: entries.first.url,
                entry: entry,
              ),
            ),
      );
    }

    return SearchIndexOutput(
      manifestJson: jsonEncode({
        'version': 4,
        'entryCount': pageEntries.length + sectionEntries.length,
        'pageEntryCount': pageEntries.length,
        'sectionEntryCount': sectionEntries.length,
        'pages': '/generated/search_pages.json',
        'sections': '/generated/search_sections.json',
        'sectionsContent': '/generated/search_sections_content.json',
      }),
      pagesJson: _encodeEntries(pageEntries),
      sectionsJson: _encodeSectionEntries(sectionEntries),
      sectionsContentJson: _encodeSectionContentEntries(sectionEntries),
    );
  }

  String _encodeEntries(List<SearchIndexEntry> entries) => jsonEncode({
        'version': 2,
        'entryCount': entries.length,
        'entries': [
          for (final entry in entries) entry.toJson(),
        ],
      });

  String _encodeSectionEntries(List<SectionIndexEntry> entries) => jsonEncode({
        'version': 3,
        'entryCount': entries.length,
        'entries': [
          for (final entry in entries) entry.toMetaJson(),
        ],
      });

  String _encodeSectionContentEntries(List<SectionIndexEntry> entries) =>
      jsonEncode({
        'version': 4,
        'entryCount': entries.where((entry) => entry.content.isNotEmpty).length,
        'entries': [
          for (final entry in entries)
            if (entry.content.isNotEmpty) entry.toContentJson(),
        ],
      });

  @visibleForTesting
  static List<SearchIndexEntry> buildEntriesForPage({
    required String relativePath,
    required String markdown,
  }) {
    final parsed = _ParsedPage.parse(relativePath, markdown);
    final pageTitle = parsed.pageTitle;
    final pageSummary = _excerpt(
        parsed.description.isNotEmpty ? parsed.description : parsed.introText);
    final pageText = _compactSearchText(
      summary: pageSummary,
      text: [
        if (parsed.description.isNotEmpty) parsed.description,
        parsed.introText,
      ].where((part) => part.isNotEmpty).join(' '),
    );

    final entries = <SearchIndexEntry>[
      SearchIndexEntry(
        kind: parsed.kind,
        title: pageTitle,
        section: null,
        url: parsed.url,
        summary: pageSummary,
        searchText: pageText,
      ),
    ];

    for (final section in parsed.sections) {
      if (!_shouldIndexSection(section)) {
        continue;
      }

      final sectionText = _compactSearchText(
        summary: _excerpt(
          section.text.isNotEmpty ? section.text : section.heading,
        ),
        text: section.text,
      );
      final sectionSummary = _excerpt(
        section.text.isNotEmpty ? section.text : section.heading,
      );

      entries.add(
        SearchIndexEntry(
          kind: parsed.kind,
          title: pageTitle,
          section: section.heading,
          url: '${parsed.url}#${section.anchor}',
          summary: sectionSummary,
          searchText: sectionText,
        ),
      );
    }

    return entries;
  }
}

class SearchIndexOutput {
  const SearchIndexOutput({
    required this.manifestJson,
    required this.pagesJson,
    required this.sectionsJson,
    required this.sectionsContentJson,
  });

  final String manifestJson;
  final String pagesJson;
  final String sectionsJson;
  final String sectionsContentJson;
}

class SearchIndexEntry {
  const SearchIndexEntry({
    required this.kind,
    required this.title,
    required this.section,
    required this.url,
    required this.summary,
    required this.searchText,
  });

  final String kind;
  final String title;
  final String? section;
  final String url;
  final String summary;
  final String searchText;

  List<Object?> toJson() {
    final compact = <Object?>[
      kind,
      title,
      url,
      section,
      summary.isEmpty ? null : summary,
      searchText.isEmpty ? null : searchText,
    ];
    while (compact.isNotEmpty && compact.last == null) {
      compact.removeLast();
    }
    return compact;
  }
}

class SectionIndexEntry {
  const SectionIndexEntry({
    required this.pageIndex,
    required this.anchor,
    required this.section,
    required this.content,
  });

  factory SectionIndexEntry.fromPageEntry({
    required int pageIndex,
    required String pageUrl,
    required SearchIndexEntry entry,
  }) {
    final anchor = entry.url.startsWith('$pageUrl#')
        ? entry.url.substring(pageUrl.length + 1)
        : sanitizeAnchor(entry.section ?? '');
    return SectionIndexEntry(
      pageIndex: pageIndex,
      anchor: anchor,
      section: entry.section ?? '',
      content: entry.searchText.isNotEmpty ? entry.searchText : entry.summary,
    );
  }

  final int pageIndex;
  final String anchor;
  final String section;
  final String content;

  List<Object?> toMetaJson() {
    final compact = <Object?>[
      pageIndex,
      anchor,
      section,
    ];
    while (compact.isNotEmpty && compact.last == null) {
      compact.removeLast();
    }
    return compact;
  }

  List<Object?> toContentJson() {
    final compact = <Object?>[
      pageIndex,
      anchor,
      content.isEmpty ? null : content,
    ];
    while (compact.isNotEmpty && compact.last == null) {
      compact.removeLast();
    }
    return compact;
  }
}

class _ParsedPage {
  _ParsedPage({
    required this.kind,
    required this.url,
    required this.pageTitle,
    required this.description,
    required this.introText,
    required this.sections,
  });

  final String kind;
  final String url;
  final String pageTitle;
  final String description;
  final String introText;
  final List<_ParsedSection> sections;

  static final _frontmatterField = RegExp(r'^([A-Za-z][\w-]*):\s*(.*)$');
  static final _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*$');
  static final _explicitHeadingAnchor = RegExp(
    r'\s+\{#([A-Za-z0-9:_\-.]+)\}\s*$',
  );
  static final _fence = RegExp(r'^\s*(```|~~~)');

  static _ParsedPage parse(String relativePath, String markdown) {
    final split = _splitFrontmatter(markdown);
    final url = _pathToUrl(relativePath);
    final kind = _kindForPath(relativePath);
    final bodyLines = split.body.split('\n');
    final firstHeading = _firstHeading(bodyLines);
    final pageTitle = split.metadata['title']?.trim().isNotEmpty == true
        ? split.metadata['title']!.trim()
        : (firstHeading ?? _fallbackTitle(relativePath));

    final introBuffer = StringBuffer();
    final sections = <_ParsedSection>[];
    _SectionBuffer? currentSection;
    var inFence = false;

    for (final line in bodyLines) {
      if (_fence.hasMatch(line)) {
        inFence = !inFence;
      }

      final headingMatch = !inFence ? _heading.firstMatch(line) : null;
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final rawHeading = headingMatch.group(2)!.trim();
        final explicitAnchor = _explicitHeadingAnchor.firstMatch(rawHeading);
        final headingText = _normalizeText(
          rawHeading.replaceFirst(_explicitHeadingAnchor, ''),
        );
        if (headingText.isEmpty) continue;

        if (level == 1) {
          continue;
        }

        if (currentSection != null) {
          sections.add(currentSection.finish());
        }
        currentSection = _SectionBuffer(
          headingText,
          anchor: explicitAnchor?.group(1),
        );
        continue;
      }

      if (currentSection != null) {
        currentSection.addLine(line);
      } else {
        introBuffer.writeln(line);
      }
    }

    if (currentSection != null) {
      sections.add(currentSection.finish());
    }

    return _ParsedPage(
      kind: kind,
      url: url,
      pageTitle: pageTitle,
      description: _normalizeText(split.metadata['description'] ?? ''),
      introText: _normalizeText(introBuffer.toString()),
      sections:
          sections.where((section) => section.heading.isNotEmpty).toList(),
    );
  }

  static ({Map<String, String> metadata, String body}) _splitFrontmatter(
    String markdown,
  ) {
    if (!markdown.startsWith('---\n')) {
      return (metadata: const {}, body: markdown);
    }

    final lines = markdown.split('\n');
    final metadata = <String, String>{};
    var index = 1;
    for (; index < lines.length; index++) {
      final line = lines[index];
      if (line.trim() == '---') {
        index++;
        break;
      }

      final match = _frontmatterField.firstMatch(line);
      if (match == null) continue;
      metadata[match.group(1)!] = _cleanFrontmatterValue(match.group(2)!);
    }

    return (
      metadata: metadata,
      body: lines.skip(index).join('\n'),
    );
  }

  static String? _firstHeading(List<String> lines) {
    var inFence = false;
    for (final line in lines) {
      if (_fence.hasMatch(line)) {
        inFence = !inFence;
        continue;
      }

      if (inFence) continue;

      final match = _heading.firstMatch(line);
      if (match != null && match.group(1)!.length == 1) {
        final heading = _normalizeText(match.group(2)!);
        if (heading.isNotEmpty) return heading;
      }
    }
    return null;
  }

  static String _pathToUrl(String relativePath) {
    final withoutPrefix = relativePath.replaceFirst(RegExp(r'^content/'), '');
    final noExt = withoutPrefix.replaceFirst(RegExp(r'\.md$'), '');
    if (noExt == 'index') return '/';
    if (noExt.endsWith('/index')) {
      return '/${noExt.substring(0, noExt.length - '/index'.length)}';
    }
    return '/$noExt';
  }

  static String _kindForPath(String relativePath) {
    if (relativePath.startsWith('content/api/')) return 'api';
    if (relativePath.startsWith('content/guide/')) return 'guide';
    if (relativePath.startsWith('content/topics/')) return 'topic';
    return 'page';
  }

  static String _fallbackTitle(String relativePath) {
    final basename = p.basenameWithoutExtension(relativePath);
    if (basename == 'index') {
      final parent = p.basename(p.dirname(relativePath));
      if (parent.isNotEmpty && parent != 'content') {
        return parent.replaceAll('-', ' ');
      }
      return 'Overview';
    }
    return basename.replaceAll('-', ' ');
  }
}

class _SectionBuffer {
  _SectionBuffer(this.heading, {this.anchor});

  final String heading;
  final String? anchor;
  final StringBuffer _buffer = StringBuffer();

  void addLine(String line) {
    _buffer.writeln(line);
  }

  _ParsedSection finish() {
    return _ParsedSection(
      heading: heading,
      anchor: anchor ?? sanitizeAnchor(heading),
      text: _normalizeText(_buffer.toString()),
    );
  }
}

class _ParsedSection {
  const _ParsedSection({
    required this.heading,
    required this.anchor,
    required this.text,
  });

  final String heading;
  final String anchor;
  final String text;
}

final _structuralSectionHeadings = <String>{
  'annotations',
  'classes',
  'constants',
  'constructors',
  'enums',
  'extension types',
  'extensions',
  'functions',
  'implementers',
  'methods',
  'mixins',
  'operators',
  'properties',
  'typedefs',
  'values',
};

final _objectMemberHeadings = <String>{
  'hashcode',
  'nosuchmethod',
  'operator',
  'runtimetype',
  'tostring',
};

bool _shouldIndexSection(_ParsedSection section) {
  final headingKey = _normalizeHeadingKey(section.heading);
  if (headingKey.isEmpty) return false;
  if (_structuralSectionHeadings.contains(headingKey)) return false;
  if (section.text.isEmpty) return false;

  if (_objectMemberHeadings.contains(headingKey) &&
      section.text.contains('Inherited from Object.')) {
    return false;
  }

  return true;
}

String _normalizeHeadingKey(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String _cleanFrontmatterValue(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2) {
    final startsWithDouble = trimmed.startsWith('"') && trimmed.endsWith('"');
    final startsWithSingle = trimmed.startsWith("'") && trimmed.endsWith("'");
    if (startsWithDouble || startsWithSingle) {
      return trimmed.substring(1, trimmed.length - 1).trim();
    }
  }
  return trimmed;
}

String _normalizeText(String value) {
  var normalized = value
      .replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), ' ')
      .replaceAll(RegExp(r'~~~[\s\S]*?~~~', multiLine: true), ' ')
      .replaceAllMapped(
        RegExp(r'\[(.*?)\]\((.*?)\)'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'`([^`]+)`'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r'^:::\s*([\w-]+)\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^:::\s*$', multiLine: true), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\bInherited from [^.]+\.\s*'), ' ')
      .replaceAll(RegExp(r'\bImplementation\b'), ' ')
      .replaceAll(RegExp(r'^[#>\-\*\+\d\.\)\s]+', multiLine: true), ' ')
      .replaceAll(RegExp(r'[_*~]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return normalized;
}

String _truncate(String value, [int maxLength = 320]) {
  if (value.length <= maxLength) return value;
  const tailLength = 48;
  if (maxLength <= tailLength + 5) {
    return value.substring(0, maxLength).trimRight();
  }

  final headLength = maxLength - tailLength - 3;
  final head = value.substring(0, headLength).trimRight();
  final tail = value.substring(value.length - tailLength).trimLeft();
  return '$head...$tail';
}

String _excerpt(String value, [int maxLength = 180]) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '';
  if (normalized.length <= maxLength) return normalized;

  final slice = normalized.substring(0, maxLength);
  final lastSpace = slice.lastIndexOf(' ');
  if (lastSpace <= maxLength ~/ 2) {
    return '$slice...';
  }
  return '${slice.substring(0, lastSpace)}...';
}

String _compactSearchText({
  required String summary,
  required String text,
  int maxLength = 220,
}) {
  final normalizedText = _normalizeText(text);
  if (normalizedText.isEmpty) return '';

  final normalizedSummary = _normalizeText(summary);
  if (normalizedSummary.isNotEmpty) {
    if (normalizedText == normalizedSummary) {
      return '';
    }
    if (normalizedText.startsWith(normalizedSummary) &&
        normalizedText.length <= normalizedSummary.length + 48) {
      return '';
    }
  }

  return _truncate(normalizedText, maxLength);
}
