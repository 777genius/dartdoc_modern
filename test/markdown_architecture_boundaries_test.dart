import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:dartdoc_modern/src/generator/core/markdown_paths.dart';
import 'package:dartdoc_modern/src/generator/core/no_op_templates.dart';
import 'package:dartdoc_modern/src/generator/jaspr/paths.dart';
import 'package:dartdoc_modern/src/generator/vitepress/paths.dart';
import 'package:dartdoc_modern/src/generator/templates.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Inspect Dart directives instead of matching arbitrary source substrings.
// Resolve relative URIs and conditional alternatives before comparing layers.
Iterable<String> _namespaceDependencies(String filePath, String source) sync* {
  final unit = parseString(
    content: source,
    path: filePath,
    throwIfDiagnostics: false,
  ).unit;
  for (final directive in unit.directives.whereType<NamespaceDirective>()) {
    final uris = <String?>[
      directive.uri.stringValue,
      for (final condition in directive.configurations) condition.uri.stringValue,
    ];
    for (final uri in uris) {
      if (uri == null) continue;
      if (uri.startsWith('package:dartdoc_modern/')) {
        yield 'lib/' + uri.substring('package:dartdoc_modern/'.length);
      } else if (!uri.startsWith('dart:') && !uri.startsWith('package:')) {
        yield p.normalize(p.join(p.dirname(filePath), uri)).replaceAll('\\', '/');
      }
    }
  }
}

bool _dependsOnBackend(String path, String source, String backend) =>
    _namespaceDependencies(
      path,
      source,
    ).any((uri) => uri.startsWith('lib/src/generator/$backend/'));

void main() {
  test('both backends use the same Markdown path contract', () {
    expect(VitePressPathResolver(), isA<MarkdownPathResolver>());
    expect(JasprPathResolver(), isA<MarkdownPathResolver>());
  });

  test('both backends share the HTML template compatibility adapter', () {
    expect(NoOpTemplates(), isA<Templates>());
  });

  test('shared Markdown core does not import either concrete backend', () {
    for (final file in [
      'lib/src/generator/core/markdown_paths.dart',
      'lib/src/generator/core/markdown_docs.dart',
      'lib/src/generator/core/api_markdown_renderer.dart',
      'lib/src/generator/core/no_op_templates.dart',
    ]) {
      final source = File(file).readAsStringSync();
      expect(_dependsOnBackend(file, source, 'vitepress'), isFalse, reason: file);
      expect(_dependsOnBackend(file, source, 'jaspr'), isFalse, reason: file);
    }
  });

  test('Jaspr rendering has no concrete VitePress imports', () {
    for (final file in [
      'lib/src/generator/jaspr/paths.dart',
      'lib/src/generator/jaspr/docs.dart',
      'lib/src/generator/jaspr/backend.dart',
    ]) {
      final source = File(file).readAsStringSync();
      expect(_dependsOnBackend(file, source, 'vitepress'), isFalse, reason: file);
    }
  });

  test('resolves relative, package and conditional imports and exports', () {
    const path = 'lib/src/generator/core/markdown_docs.dart';
    const source = '''
// import 'package:dartdoc_modern/src/generator/fake/comment.dart';
import '../vitepress/backend.dart'
    if (dart.library.io) '../jaspr/backend.dart';
export 'package:dartdoc_modern/src/generator/core/markdown_paths.dart';
''';
    final dependencies = _namespaceDependencies(path, source).toList();
    expect(dependencies, contains('lib/src/generator/vitepress/backend.dart'));
    expect(dependencies, contains('lib/src/generator/jaspr/backend.dart'));
    expect(dependencies, contains('lib/src/generator/core/markdown_paths.dart'));
    expect(
      dependencies.any((uri) => uri.contains('/fake/comment.dart')),
      isFalse,
    );
  });
}
