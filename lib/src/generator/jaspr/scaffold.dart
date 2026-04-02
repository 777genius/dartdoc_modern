// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/file_system/file_system.dart';
import 'package:dartdoc_vitepress/src/generator/generator.dart';
import 'package:dartdoc_vitepress/src/generator/resource_loader.dart';
import 'package:path/path.dart' as p;

/// Generates initial Jaspr project scaffold files.
///
/// Creates the following files (only if they don't already exist):
/// - `pubspec.yaml` with Jaspr dependencies
/// - `lib/main.server.dart` with ContentApp configuration
/// - `lib/main.client.dart` for client-side hydration
/// - `content/index.md` homepage
///
/// Templates are stored in `lib/resources/jaspr/`.
class JasprInitGenerator {
  final FileWriter writer;
  final ResourceProvider resourceProvider;
  final String outputPath;

  static const _templatePrefix = 'package:dartdoc_vitepress/resources/jaspr';

  JasprInitGenerator({
    required this.writer,
    required this.resourceProvider,
    required this.outputPath,
  });

  /// Generates scaffold files. Only creates files that don't exist.
  Future<void> generate({
    required String packageName,
    String repositoryUrl = '',
  }) async {
    final safeName = packageName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-')
        .toLowerCase();
    final placeholders = {
      '{{packageName}}': packageName,
      '{{safePackageName}}': safeName,
      '{{repositoryUrl}}': repositoryUrl,
    };

    final templateDir = (await resourceProvider.getResourceFolder(
      _templatePrefix,
    )).path;

    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: 'pubspec.yaml',
      outputFile: 'pubspec.yaml',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'app.dart'),
      outputFile: 'lib/app.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'docs_base.dart'),
      outputFile: 'lib/docs_base.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'main.server.dart'),
      outputFile: 'lib/main.server.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'main.client.dart'),
      outputFile: 'lib/main.client.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'main.client.options.dart'),
      outputFile: 'lib/main.client.options.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'main.server.options.dart'),
      outputFile: 'lib/main.server.options.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_code_block.dart'),
      outputFile: 'lib/components/docs_code_block.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_search.dart'),
      outputFile: 'lib/components/docs_search.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_navigation_runtime.dart'),
      outputFile: 'lib/components/docs_navigation_runtime.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_navigation_runtime_stub.dart',
      ),
      outputFile: 'lib/components/docs_navigation_runtime_stub.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_navigation_runtime_web.dart',
      ),
      outputFile: 'lib/components/docs_navigation_runtime_web.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_disclosure_runtime.dart'),
      outputFile: 'lib/components/docs_disclosure_runtime.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_disclosure_runtime_stub.dart',
      ),
      outputFile: 'lib/components/docs_disclosure_runtime_stub.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_disclosure_runtime_web.dart',
      ),
      outputFile: 'lib/components/docs_disclosure_runtime_web.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_lightbox_runtime.dart'),
      outputFile: 'lib/components/docs_lightbox_runtime.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_lightbox_runtime_stub.dart',
      ),
      outputFile: 'lib/components/docs_lightbox_runtime_stub.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_lightbox_runtime_web.dart',
      ),
      outputFile: 'lib/components/docs_lightbox_runtime_web.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_header.dart'),
      outputFile: 'lib/components/docs_header.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_theme_toggle.dart'),
      outputFile: 'lib/components/docs_theme_toggle.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_nav_link.dart'),
      outputFile: 'lib/components/docs_nav_link.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_sidebar.dart'),
      outputFile: 'lib/components/docs_sidebar.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_sidebar_toggle.dart'),
      outputFile: 'lib/components/docs_sidebar_toggle.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_dartpad_runtime.dart'),
      outputFile: 'lib/components/docs_dartpad_runtime.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_dartpad_runtime_stub.dart',
      ),
      outputFile: 'lib/components/docs_dartpad_runtime_stub.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_dartpad_runtime_web.dart',
      ),
      outputFile: 'lib/components/docs_dartpad_runtime_web.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_mermaid_runtime.dart'),
      outputFile: 'lib/components/docs_mermaid_runtime.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_mermaid_runtime_stub.dart',
      ),
      outputFile: 'lib/components/docs_mermaid_runtime_stub.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'components',
        'docs_mermaid_runtime_web.dart',
      ),
      outputFile: 'lib/components/docs_mermaid_runtime_web.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_toc_runtime.dart'),
      outputFile: 'lib/components/docs_toc_runtime.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_toc_runtime_stub.dart'),
      outputFile: 'lib/components/docs_toc_runtime_stub.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'docs_toc_runtime_web.dart'),
      outputFile: 'lib/components/docs_toc_runtime_web.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'dart_pad.dart'),
      outputFile: 'lib/components/dart_pad.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'components', 'mermaid_diagram.dart'),
      outputFile: 'lib/components/mermaid_diagram.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'extensions', 'api_linker_extension.dart'),
      outputFile: 'lib/extensions/api_linker_extension.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'extensions',
        'base_path_link_extension.dart',
      ),
      outputFile: 'lib/extensions/base_path_link_extension.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'layouts', 'api_docs_layout.dart'),
      outputFile: 'lib/layouts/api_docs_layout.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join(
        'lib',
        'template_engine',
        'docs_template_engine.dart',
      ),
      outputFile: 'lib/template_engine/docs_template_engine.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'theme', 'docs_theme.dart'),
      outputFile: 'lib/theme/docs_theme.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('lib', 'theme', 'docs_responsive.dart'),
      outputFile: 'lib/theme/docs_responsive.dart',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('content', 'index.md'),
      outputFile: 'content/index.md',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: '.gitignore',
      outputFile: '.gitignore',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('web', 'docs_mermaid_runtime.js'),
      outputFile: 'web/docs_mermaid_runtime.js',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('web', 'docs_lightbox_runtime.js'),
      outputFile: 'web/docs_lightbox_runtime.js',
      placeholders: placeholders,
    );
    _writeTemplateIfAbsent(
      templateDir: templateDir,
      templateFile: p.join('web', 'favicon.svg'),
      outputFile: 'web/favicon.svg',
      placeholders: placeholders,
    );

    // Generate empty sidebar stub so the app compiles before first generation.
    _writeFileToDisk(
      outputFile: 'lib/generated/api_sidebar.dart',
      content: _emptySidebarStub('apiSidebarGroups'),
    );
    _writeFileToDisk(
      outputFile: 'lib/generated/guide_sidebar.dart',
      content: _emptySidebarStub('guideSidebarGroups'),
    );
    _writeFileToDisk(
      outputFile: 'lib/generated/api_symbols.dart',
      content: _emptyApiSymbolsStub(),
    );
  }

  void _writeFileToDisk({required String outputFile, required String content}) {
    final fullOutputPath = p.normalize(p.join(outputPath, outputFile));
    final existingFile = resourceProvider.getFile(fullOutputPath);
    if (existingFile.exists) return;

    final parent = existingFile.parent;
    if (!parent.exists) parent.create();
    existingFile.writeAsStringSync(content);
  }

  void _writeTemplateIfAbsent({
    required String templateDir,
    required String templateFile,
    required String outputFile,
    required Map<String, String> placeholders,
  }) {
    final fullOutputPath = p.normalize(p.join(outputPath, outputFile));
    final existingFile = resourceProvider.getFile(fullOutputPath);
    if (existingFile.exists) return;

    final templatePath = p.join(templateDir, templateFile);
    var content = resourceProvider.getFile(templatePath).readAsStringSync();

    for (final entry in placeholders.entries) {
      content = content.replaceAll(entry.key, entry.value);
    }

    writer.write(outputFile, content);
  }

  static String _emptySidebarStub(String constantName) =>
      '''
// Generated by dartdoc_vitepress. Do not edit.
class SidebarItem {
  final String text;
  final String? link;
  final bool collapsed;
  final List<SidebarItem> items;

  const SidebarItem({
    required this.text,
    this.link,
    this.collapsed = false,
    this.items = const <SidebarItem>[],
  });
}

class SidebarGroup {
  final String? title;
  final List<SidebarItem> items;

  const SidebarGroup({this.title, required this.items});
}

const $constantName = <SidebarGroup>[];
''';

  static String _emptyApiSymbolsStub() => '''
// Generated by dartdoc_vitepress. Do not edit.
class ApiSymbolEntry {
  final String href;
  final String relativePath;
  final String apiDir;

  const ApiSymbolEntry({
    required this.href,
    required this.relativePath,
    required this.apiDir,
  });
}

const apiSymbolMap = <String, List<ApiSymbolEntry>>{};
''';
}
