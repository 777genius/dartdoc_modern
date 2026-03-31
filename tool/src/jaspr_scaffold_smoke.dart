import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class JasprScaffoldSmokeChecker {
  JasprScaffoldSmokeChecker(this.outputDir);

  final Directory outputDir;

  void run() {
    _requireDirectory(outputDir.path);
    _requireFile('pubspec.yaml');
    _requireFile('lib/main.server.dart');
    _requireFile('lib/main.client.dart');
    _requireFile('web/index.html');
    _requireFile('web/generated/search_index.json');
    _requireFile('web/generated/search_pages.json');
    _requireFile('web/generated/search_sections.json');
    _requireFile('web/generated/search_sections_content.json');
    _requireFile('web/generated/api_styles.css');
    _requireFile('lib/generated/api_sidebar.dart');
    _requireFile('lib/layouts/api_docs_layout.dart');

    final packageName = _readPubspecPackageName();
    final generatedRoot = p.join(
      outputDir.path,
      '.dart_tool',
      'build',
      'generated',
      packageName,
    );

    _requireFile(
      p.relative(
        p.join(generatedRoot, 'web', 'main.client.module.library'),
        from: outputDir.path,
      ),
    );
    _requireFile(
      p.relative(
        p.join(generatedRoot, 'lib', 'main.client.module.library'),
        from: outputDir.path,
      ),
    );
    _requireFile(
      p.relative(
        p.join(generatedRoot, 'lib', 'components', 'dart_pad.module.library'),
        from: outputDir.path,
      ),
    );
    _requireFile(
      p.relative(
        p.join(
          generatedRoot,
          'lib',
          'components',
          'mermaid_diagram.module.library',
        ),
        from: outputDir.path,
      ),
    );
    _requireFile(
      p.relative(
        p.join(
          generatedRoot,
          'lib',
          'extensions',
          'api_linker_extension.module.library',
        ),
        from: outputDir.path,
      ),
    );
    _requireFile(
      p.relative(
        p.join(
          generatedRoot,
          'lib',
          'layouts',
          'api_docs_layout.module.library',
        ),
        from: outputDir.path,
      ),
    );

    final searchIndex = _readSearchIndex();
    final pagesPath = searchIndex['pages'] as String?;
    final sectionsPath = searchIndex['sections'] as String?;
    final sectionsContentPath = searchIndex['sectionsContent'] as String?;
    if (pagesPath == null || sectionsPath == null || sectionsContentPath == null) {
      throw StateError('search index manifest is missing chunk paths');
    }

    final pages = _readSearchEntries(pagesPath);
    final entries = [
      ...pages,
      ..._readSearchEntries(sectionsPath, pages: pages),
    ];
    if (entries.isEmpty) throw StateError('search index is empty');

    final urls = entries.map(_entryUrl).whereType<String>().toSet();
    if (!urls.any((url) => url.startsWith('/api/'))) {
      throw StateError('search index does not contain API entries');
    }

    final hasGuideContent =
        Directory(p.join(outputDir.path, 'content', 'guide')).existsSync();
    if (hasGuideContent && !urls.any((url) => url.startsWith('/guide/'))) {
      throw StateError('search index does not contain guide entries');
    }
  }

  Map<String, Object?> _readSearchIndex() {
    final raw =
        File(p.join(outputDir.path, 'web', 'generated', 'search_index.json'))
            .readAsStringSync();
    return jsonDecode(raw) as Map<String, Object?>;
  }

  List<Object?> _readSearchEntries(
    String relativePath, {
    List<Object?> pages = const [],
  }) {
    final normalizedPath =
        relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    final raw =
        File(p.join(outputDir.path, 'web', normalizedPath)).readAsStringSync();
    final payload = jsonDecode(raw) as Map<String, Object?>;
    return ((payload['entries'] as List<Object?>?) ?? const [])
        .map((entry) => _normalizeEntry(entry, pages))
        .toList(growable: false);
  }

  String _readPubspecPackageName() {
    final pubspec = File(p.join(outputDir.path, 'pubspec.yaml')).readAsLinesSync();
    for (final line in pubspec) {
      final trimmed = line.trim();
      if (trimmed.startsWith('name:')) {
        return trimmed.substring('name:'.length).trim();
      }
    }
    throw StateError('Could not find package name in pubspec.yaml');
  }

  void _requireDirectory(String path) {
    if (!Directory(path).existsSync()) {
      throw StateError('Directory not found: $path');
    }
  }

  void _requireFile(String relativePath) {
    final file = File(p.join(outputDir.path, relativePath));
    if (!file.existsSync()) {
      throw StateError('Required file not found: $relativePath');
    }
  }
}

String? _entryUrl(Object? entry) {
  if (entry is List<Object?>) {
    return entry.length > 2 ? entry[2] as String? : null;
  }
  if (entry is Map<Object?, Object?>) {
    return entry['url'] as String?;
  }
  return null;
}

Object? _normalizeEntry(Object? entry, List<Object?> pages) {
  if (entry is List<Object?> && entry.isNotEmpty && entry.first is int) {
    final pageIndex = entry.first as int;
    final page =
        pageIndex >= 0 && pageIndex < pages.length ? pages[pageIndex] : null;
    final pageUrl = _entryUrl(page) ?? '';
    final anchor = entry.length > 1 ? entry[1] as String? ?? '' : '';
    return {
      'url': anchor.isEmpty ? pageUrl : '$pageUrl#$anchor',
    };
  }
  return entry;
}
