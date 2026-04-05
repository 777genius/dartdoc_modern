// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Format-agnostic guide file collection and parsing.
///
/// Collects markdown files from package `doc/`/`docs/` directories,
/// extracts titles and frontmatter, and returns structured [GuideEntry]
/// objects. Sidebar output formatting is format-specific and NOT included here.
library;

import 'package:analyzer/file_system/file_system.dart';
import 'package:dartdoc_modern/src/logging.dart';
import 'package:dartdoc_modern/src/model/model.dart';
import 'package:path/path.dart' as p;

/// Matches a markdown level-1 heading (e.g. `# My Title`).
final _headingPattern = RegExp(r'^#\s+(.+)$');

/// Matches inline markdown formatting (`**bold**`, `*italic*`, `` `code` ``).
final _inlineMarkdown = RegExp(r'\*{1,2}|`');

/// Matches hyphens or underscores for kebab/snake-case splitting.
final _kebabSnakeDelimiter = RegExp(r'[-_]');

/// Matches YAML frontmatter block delimited by `---`.
final frontmatterPattern = RegExp(r'^---\n([\s\S]*?)\n---', multiLine: true);

/// Matches `sidebar_position: <number>` in frontmatter.
final _sidebarPositionPattern = RegExp(
  r'^sidebar_position:\s*(\d+)\s*$',
  multiLine: true,
);

/// Matches `internal: true` in frontmatter.
final _internalGuidePattern = RegExp(
  r'^internal:\s*true\s*$',
  multiLine: true,
  caseSensitive: false,
);

/// Matches `published: false` in frontmatter.
final _unpublishedGuidePattern = RegExp(
  r'^published:\s*false\s*$',
  multiLine: true,
  caseSensitive: false,
);

/// An entry representing a single guide markdown file.
class GuideEntry {
  final String packageName;

  /// Output path relative to the output root (e.g. `guide/pkg/intro.md`).
  final String relativePath;

  final String title;

  /// The raw markdown content read from the source file.
  final String content;

  /// Absolute source path of the original markdown file.
  ///
  /// Used by format-specific preprocessors that need filesystem context,
  /// for example resolving `<<<` code imports relative to the guide file.
  final String? sourcePath;

  /// Optional sidebar position from frontmatter `sidebar_position`.
  /// Lower values appear first. `null` means no explicit order (sorted last).
  final int? sidebarPosition;

  GuideEntry({
    required this.packageName,
    required this.relativePath,
    required this.title,
    required this.content,
    this.sourcePath,
    this.sidebarPosition,
  });
}

/// Applies format-specific content transformations to collected guide files.
typedef GuideContentTransformer =
    String Function(String content, String relativePath, String sourcePath);

/// Scans and collects markdown guide files in a format-agnostic way.
///
/// This class is responsible only for:
/// - directory scanning
/// - include/exclude filtering
/// - title extraction
/// - sidebar position extraction
/// - duplicate output path protection
///
/// Output formatting and content rendering remain format-specific.
class GuideCollector {
  final ResourceProvider resourceProvider;
  final List<String> scanDirs;
  final List<RegExp> _includeRegexps;
  final List<RegExp> _excludeRegexps;

  GuideCollector({
    required this.resourceProvider,
    required this.scanDirs,
    List<String> include = const [],
    List<String> exclude = const [],
  }) : _includeRegexps = compilePatterns(include, 'include'),
       _excludeRegexps = compilePatterns(exclude, 'exclude');

  /// Compiles regex patterns with validation.
  static List<RegExp> compilePatterns(List<String> patterns, String label) {
    return patterns.map((pattern) {
      try {
        return RegExp(pattern);
      } on FormatException catch (e) {
        throw FormatException(
          'Invalid guide $label regex "$pattern": ${e.message}',
        );
      }
    }).toList();
  }

  /// Scans `doc/`/`docs/` in each local package and collects `.md` files.
  List<GuideEntry> collectGuideEntries({
    required PackageGraph packageGraph,
    required bool isMultiPackage,
    required GuideContentTransformer transformContent,
  }) {
    final entries = <GuideEntry>[];
    final usedPaths = <String>{};

    for (final package in packageGraph.localPackages) {
      final packageDir = package.packagePath;

      for (final dirName in scanDirs) {
        final docDirPath = p.join(packageDir, dirName);
        final docFolder = resourceProvider.getFolder(docDirPath);
        if (!docFolder.exists) continue;

        final mdFiles = collectMarkdownFiles(docFolder);
        for (final mdFile in mdFiles) {
          var relativeToDocs = p.relative(mdFile.path, from: docDirPath);
          relativeToDocs = relativeToDocs.replaceAll(r'\', '/');

          if (!matchesFilters(relativeToDocs)) continue;

          final originalContent = mdFile.readAsStringSync();
          if (!isGuideVisible(originalContent)) continue;
          final transformedContent = transformContent(
            originalContent,
            relativeToDocs,
            mdFile.path,
          );
          final title = extractTitle(originalContent, relativeToDocs);

          final outputRelative = isMultiPackage
              ? p.posix.join('guide', package.name, relativeToDocs)
              : p.posix.join('guide', relativeToDocs);

          if (!usedPaths.add(outputRelative)) {
            logWarning('Duplicate guide file path: $outputRelative (skipping)');
            continue;
          }

          entries.add(
            GuideEntry(
              packageName: package.name,
              relativePath: outputRelative,
              title: title,
              content: transformedContent,
              sourcePath: mdFile.path,
              sidebarPosition: extractSidebarPosition(originalContent),
            ),
          );
        }
      }
    }

    if (entries.isNotEmpty) {
      logInfo('Guide: ${entries.length} markdown file(s) collected.');
    }

    return entries;
  }

  /// Checks if [relativePath] passes the include/exclude filters.
  bool matchesFilters(String relativePath) {
    if (_includeRegexps.isNotEmpty) {
      final matches = _includeRegexps.any((re) => re.hasMatch(relativePath));
      if (!matches) return false;
    }

    if (_excludeRegexps.isNotEmpty) {
      final excluded = _excludeRegexps.any((re) => re.hasMatch(relativePath));
      if (excluded) return false;
    }

    return true;
  }

  /// Recursively collects all `.md` files in [folder].
  ///
  /// Tracks visited canonical paths to prevent infinite loops from symlinks.
  List<File> collectMarkdownFiles(Folder folder, [Set<String>? visited]) {
    visited ??= {};
    final resolvedPath = folder.resolveSymbolicLinksSync().path;
    if (!visited.add(resolvedPath)) return [];

    final files = <File>[];

    for (final child in folder.getChildren()) {
      if (child is Folder) {
        files.addAll(collectMarkdownFiles(child, visited));
      } else if (child is File && child.path.endsWith('.md')) {
        files.add(child);
      }
    }

    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}

/// Extracts a title from the markdown content.
///
/// Looks for the first `# heading` line. Falls back to the file name
/// (without extension) converted from kebab/snake case to title case.
String extractTitle(String content, String relativePath) {
  final lines = content.split('\n');
  for (final line in lines) {
    final match = _headingPattern.firstMatch(line.trim());
    if (match != null) {
      return _stripInlineMarkdown(match.group(1)!.trim());
    }
  }

  // Fallback: use the file name.
  var name = p.basenameWithoutExtension(relativePath);
  // Convert kebab-case or snake_case to Title Case.
  name = name
      .replaceAll(_kebabSnakeDelimiter, ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  return name;
}

/// Strips inline markdown formatting from a heading title.
String _stripInlineMarkdown(String title) =>
    title.replaceAll(_inlineMarkdown, '').trim();

/// Extracts `sidebar_position` from YAML frontmatter if present.
int? extractSidebarPosition(String content) {
  final fmMatch = frontmatterPattern.firstMatch(content);
  if (fmMatch == null) return null;
  final posMatch = _sidebarPositionPattern.firstMatch(fmMatch.group(1)!);
  if (posMatch == null) return null;
  return int.tryParse(posMatch.group(1)!);
}

/// Whether the guide should be exposed in generated user-facing docs.
///
/// Internal guides remain in the repository but are skipped during guide
/// collection so they do not appear in generated navigation or routes.
bool isGuideVisible(String content) {
  final fmMatch = frontmatterPattern.firstMatch(content);
  if (fmMatch == null) return true;
  final frontmatter = fmMatch.group(1)!;
  return !_internalGuidePattern.hasMatch(frontmatter) &&
      !_unpublishedGuidePattern.hasMatch(frontmatter);
}

/// Sorts guide entries: by `sidebarPosition` first (ascending),
/// entries without position go last, sorted by title alphabetically.
List<GuideEntry> sortGuideEntries(List<GuideEntry> entries) {
  entries.sort((a, b) {
    if (a.sidebarPosition != null && b.sidebarPosition != null) {
      final byPosition = a.sidebarPosition!.compareTo(b.sidebarPosition!);
      if (byPosition != 0) return byPosition;
    }
    if (a.sidebarPosition != null) return -1;
    if (b.sidebarPosition != null) return 1;

    final depthA = '/'.allMatches(a.relativePath).length;
    final depthB = '/'.allMatches(b.relativePath).length;
    if (depthA != depthB) {
      return depthA.compareTo(depthB);
    }

    final aIsIndex = p.basenameWithoutExtension(a.relativePath) == 'index';
    final bIsIndex = p.basenameWithoutExtension(b.relativePath) == 'index';
    if (aIsIndex != bIsIndex) {
      return aIsIndex ? -1 : 1;
    }

    return a.title.compareTo(b.title);
  });
  return entries;
}
