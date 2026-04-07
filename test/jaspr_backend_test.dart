import 'dart:io';

import 'package:dartdoc_modern/src/dartdoc.dart';
import 'package:dartdoc_modern/src/generator/core/docs_recipe.dart'
    as docs_recipe;
import 'package:dartdoc_modern/src/generator/core/guide_collection.dart';
import 'package:dartdoc_modern/src/generator/core/legacy_guide_redirects.dart';
import 'package:dartdoc_modern/src/generator/generator_backend.dart';
import 'package:dartdoc_modern/src/generator/jaspr/backend.dart';
import 'package:dartdoc_modern/src/generator/jaspr/dart_string.dart';
import 'package:dartdoc_modern/src/generator/jaspr/paths.dart';
import 'package:dartdoc_modern/src/generator/jaspr/sidebar.dart';
import 'package:dartdoc_modern/src/package_meta.dart';
import 'package:dartdoc_modern/src/runtime_stats.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'src/utils.dart';

void main() {
  group('JasprGeneratorBackend.stripVitePressSyntaxForJaspr', () {
    test('removes VitePress-only frontmatter fields but keeps metadata', () {
      const input = '''---
title: Example
description: Example page
outlineCollapsible: true
editLink: false
prev: false
next: false
---

<ApiBreadcrumb />

# Example
''';

      expect(JasprGeneratorBackend.stripVitePressSyntaxForJaspr(input), '''---
title: Example
description: Example page
outlineCollapsible: true
---

# Example
''');
    });

    test('preserves heading anchors outside code fences for stable ids', () {
      const input = '''
## Functions {#section-functions}

```md
## Keep {#inside-code}
```
''';

      expect(JasprGeneratorBackend.stripVitePressSyntaxForJaspr(input), '''
## Functions {#section-functions}

```md
## Keep {#inside-code}
```
''');
    });

    test('unescapes Vue braces for Jaspr markdown', () {
      const input = r'''
Paragraph with \{\{ value \}\}
''';

      expect(JasprGeneratorBackend.stripVitePressSyntaxForJaspr(input), '''
Paragraph with {{ value }}
''');
    });

    test(
      'converts Badge components and removes TOC markers outside code fences',
      () {
        const input = '''
[[toc]]

# Example <Badge type="warning" text="deprecated" />

```md
[[toc]]
<Badge type="tip" text="keep" />
```
''';

        expect(JasprGeneratorBackend.stripVitePressSyntaxForJaspr(input), '''
# Example <span class="docs-badge docs-badge-warning">deprecated</span>

```md
[[toc]]
<Badge type="tip" text="keep" />
```
''');
      },
    );
  });

  group('escapeDartSingleQuotedString', () {
    test('escapes interpolation, quotes, and backslashes', () {
      expect(
        escapeDartSingleQuotedString(r"$begin\path's"),
        r"\$begin\\path\'s",
      );
    });
  });

  group('buildRecipeHomePageMarkdown', () {
    test('self-docs recipe emits Jaspr home frontmatter contract', () {
      final markdown = docs_recipe.buildRecipeHomePageMarkdown(
        docs_recipe.selfDocsRecipeName,
        packageName: 'dartdoc_modern',
        repositoryUrl: 'https://github.com/777genius/dartdoc_modern',
      );

      expect(markdown, isNotNull);
      expect(markdown, contains('layout: home'));
      expect(markdown, contains('hero:'));
      expect(markdown, contains('features:'));
      expect(markdown, contains('text: Quick Start'));
      expect(markdown, contains('text: GitHub'));
      expect(markdown, contains('<Tabs defaultValue="jaspr">'));
      expect(markdown, contains('#### Mono-repo'));
      expect(markdown, contains('## dart doc vs dartdoc_modern'));
      expect(markdown, contains('| Build speed / file count |'));
      expect(markdown, contains('### Why It Builds Much Faster'));
      expect(markdown, contains('## Live Example'));
    });
  });

  group('legacyGuideRedirectFor', () {
    test('does not generate a self-redirect for top-level guide index', () {
      expect(legacyGuideRedirectFor('guide/index.md'), isNull);
    });

    test('still generates redirects for nested guide index pages', () {
      final redirect = legacyGuideRedirectFor('guide/advanced/index.md');

      expect(redirect, isNotNull);
      expect(redirect!.outputPath, 'guide/advanced/index.html');
      expect(redirect.redirectTarget, './');
    });
  });

  group('JasprSidebarGenerator', () {
    test('generateGuide emits Dart sidebar data, not VitePress TypeScript', () {
      final generator = JasprSidebarGenerator(JasprPathResolver());
      final output = generator.generateGuide([
        GuideEntry(
          packageName: 'pkg',
          relativePath: 'guide/getting-started.md',
          title: 'Getting Started',
          content: '# Getting Started',
        ),
      ], isMultiPackage: false);

      expect(output, contains('const guideSidebarGroups = <SidebarGroup>['));
      expect(output, contains("text: 'Getting Started'"));
      expect(output, contains("link: '/guide/getting-started'"));
      expect(
        output,
        isNot(contains("import type { DefaultTheme } from 'vitepress'")),
      );
      expect(output, isNot(contains('export const guideSidebar')));
    });

    test(
      'generateGuide escapes Dart string interpolation in labels and links',
      () {
        final generator = JasprSidebarGenerator(JasprPathResolver());
        final output = generator.generateGuide([
          GuideEntry(
            packageName: 'pkg',
            relativePath: r'guide/$begin.md',
            title: r"$begin's path",
            content: '# Example',
          ),
        ], isMultiPackage: false);

        expect(output, contains(r"text: '\$begin\'s path'"));
        expect(output, contains(r"link: '/guide/\$begin'"));
      },
    );

    test('generateApi emits nested library and kind groups', () async {
      final packageGraph = await bootBasicPackage(
        'testing/test_package',
        pubPackageMetaProvider,
      );
      final generator = JasprSidebarGenerator(JasprPathResolver());

      final output = generator.generateApi(packageGraph);

      expect(output, contains('const apiSidebarGroups = <SidebarGroup>['));
      expect(output, contains("text: 'Overview'"));
      expect(output, contains("text: 'Classes'"));
      expect(output, contains("text: 'Functions'"));
      expect(output, contains('collapsed: true'));
    });
  });

  group('JasprGeneratorBackend.rewriteGuideLinksForJaspr', () {
    test('rewrites relative markdown links to Jaspr guide routes', () {
      final entries = [
        GuideEntry(
          packageName: 'pkg',
          relativePath: 'guide/getting-started.md',
          title: 'Getting Started',
          content: '''
# Getting Started

See the [Configuration](advanced/configuration.md) guide.
''',
        ),
        GuideEntry(
          packageName: 'pkg',
          relativePath: 'guide/advanced/configuration.md',
          title: 'Configuration',
          content: '# Configuration\n',
        ),
      ];

      final rewritten = JasprGeneratorBackend.rewriteGuideLinksForJaspr(
        entries,
      );
      expect(
        rewritten.first.content,
        contains('[Configuration](/guide/advanced/configuration)'),
      );
    });

    test('rewrites rooted markdown links to base-relative Jaspr routes', () {
      final entries = [
        GuideEntry(
          packageName: 'pkg',
          relativePath: 'guide/getting-started.md',
          title: 'Getting Started',
          content: '''
# Getting Started

Return to the [Guide](/guide/index.md).
''',
        ),
        GuideEntry(
          packageName: 'pkg',
          relativePath: 'guide/index.md',
          title: 'Guide',
          content: '# Guide\n',
        ),
      ];

      final rewritten = JasprGeneratorBackend.rewriteGuideLinksForJaspr(
        entries,
      );
      expect(rewritten.first.content, contains('[Guide](/guide)'));
    });

    test('rewrites same-page anchors to route-scoped Jaspr heading ids', () {
      final entries = [
        GuideEntry(
          packageName: 'pkg',
          relativePath: 'guide/spec.md',
          title: 'Spec',
          content: '''
# Spec

## 5.2. Scope Precedence Hierarchy

See [Section 5.2](#_5-2-scope-precedence-hierarchy).
''',
        ),
      ];

      final rewritten = JasprGeneratorBackend.rewriteGuideLinksForJaspr(
        entries,
      );
      expect(
        rewritten.single.content,
        contains('[Section 5.2](/guide/spec#52-scope-precedence-hierarchy)'),
      );
    });

    test('preserves valid guide heading anchors and upgrades legacy slugs', () {
      final entries = [
        GuideEntry(
          packageName: 'pkg',
          relativePath: 'guide/spec.md',
          title: 'Spec',
          content: '''
# Spec

## 3.5. Invalid Placements

## 4. Referenceable Elements

See [Section 4](#4-referenceable-elements).

#### 6.2.2. Getters and Setters

See [Section 6.2.2](#_6-2-2-getters-and-setters).
''',
        ),
      ];

      final rewritten = JasprGeneratorBackend.rewriteGuideLinksForJaspr(
        entries,
      );
      expect(
        rewritten.single.content,
        contains('[Section 4](/guide/spec#4-referenceable-elements)'),
      );
      expect(
        rewritten.single.content,
        contains('[Section 6.2.2](/guide/spec#622-getters-and-setters)'),
      );
    });
  });

  group('JasprGeneratorBackend sdk docs scaffold', () {
    test('still writes scaffold and runtime assets for sdk docs', () async {
      final assetsDir = Directory.systemTemp.createTempSync(
        'jaspr_sdk_docs_assets.',
      );
      final outDir = Directory.systemTemp.createTempSync('jaspr_sdk_docs.');
      final assetsPath = p.normalize(assetsDir.absolute.path);
      final outPath = p.normalize(outDir.absolute.path);
      final headerFile = File(p.join(assetsPath, 'header.html'))
        ..writeAsStringSync('<div>header</div>');
      final footerFile = File(p.join(assetsPath, 'footer.html'))
        ..writeAsStringSync('<div>footer</div>');
      final footerTextFile = File(p.join(assetsPath, 'footer_text.html'))
        ..writeAsStringSync('<span>footer text</span>');
      addTearDown(() => assetsDir.deleteSync(recursive: true));
      addTearDown(() => outDir.deleteSync(recursive: true));

      final context = generatorContextFromArgv([
        '--format',
        'jaspr',
        '--sdk-docs',
        '--header',
        headerFile.path,
        '--footer',
        footerFile.path,
        '--footer-text',
        footerTextFile.path,
        '--output',
        outPath,
      ], pubPackageMetaProvider);
      final options = DartdocGeneratorBackendOptions.fromContext(context);
      final writer = DartdocFileWriter(
        outPath,
        pubPackageMetaProvider.resourceProvider,
      );
      final backend = JasprGeneratorBackend(
        options,
        writer,
        pubPackageMetaProvider.resourceProvider,
        outputPath: outPath,
        packageName: 'Dart',
        sdkDocs: true,
      );

      await backend.generateAdditionalFiles();

      final packageGraph = await bootBasicPackage(
        'testing/test_package',
        pubPackageMetaProvider,
      );
      runtimeStats.resetAccumulators({'writtenPackageFileCount'});
      backend.beforeGenerate(packageGraph);
      backend.generatePackage(packageGraph, packageGraph.defaultPackage);

      bool exists(String relativePath) => pubPackageMetaProvider.resourceProvider
          .getResource(p.normalize(p.join(outPath, relativePath)))
          .exists;

      expect(exists('pubspec.yaml'), isTrue);
      expect(exists('lib/app.dart'), isTrue);
      expect(exists('lib/main.server.dart'), isTrue);
      expect(exists('web/index.html'), isTrue);
      expect(exists('web/404.html'), isTrue);
      expect(exists('web/generated/api_styles.css'), isTrue);
      expect(exists('content/index.md'), isTrue);
      expect(exists('content/guide/index.md'), isTrue);
      expect(exists('lib/generated/api_sidebar.dart'), isTrue);
      expect(exists('lib/generated/guide_sidebar.dart'), isTrue);
    });
  });
}
