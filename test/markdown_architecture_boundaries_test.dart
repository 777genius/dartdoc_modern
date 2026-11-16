import 'dart:io';

import 'package:dartdoc_modern/src/generator/core/markdown_paths.dart';
import 'package:dartdoc_modern/src/generator/core/no_op_templates.dart';
import 'package:dartdoc_modern/src/generator/jaspr/paths.dart';
import 'package:dartdoc_modern/src/generator/vitepress/paths.dart';
import 'package:dartdoc_modern/src/generator/templates.dart';
import 'package:test/test.dart';

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
      expect(
        source.contains('package:dartdoc_modern/src/generator/vitepress/'),
        isFalse,
        reason: file,
      );
      expect(
        source.contains('package:dartdoc_modern/src/generator/jaspr/'),
        isFalse,
        reason: file,
      );
    }
  });

  test('Jaspr rendering has no concrete VitePress imports', () {
    for (final file in [
      'lib/src/generator/jaspr/paths.dart',
      'lib/src/generator/jaspr/docs.dart',
      'lib/src/generator/jaspr/backend.dart',
    ]) {
      final source = File(file).readAsStringSync();
      expect(
        source.contains('package:dartdoc_modern/src/generator/vitepress/'),
        isFalse,
        reason: file,
      );
    }
  });
}
