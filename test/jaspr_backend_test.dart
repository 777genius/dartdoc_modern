import 'package:dartdoc_vitepress/src/generator/core/guide_collection.dart';
import 'package:dartdoc_vitepress/src/generator/jaspr/backend.dart';
import 'package:dartdoc_vitepress/src/generator/jaspr/paths.dart';
import 'package:dartdoc_vitepress/src/generator/jaspr/sidebar.dart';
import 'package:test/test.dart';

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

      expect(
        JasprGeneratorBackend.stripVitePressSyntaxForJaspr(input),
        '''---
title: Example
description: Example page
outlineCollapsible: true
---

# Example
''',
      );
    });

    test('strips heading anchors outside code fences only', () {
      const input = '''
## Functions {#section-functions}

```md
## Keep {#inside-code}
```
''';

      expect(
        JasprGeneratorBackend.stripVitePressSyntaxForJaspr(input),
        '''
## Functions

```md
## Keep {#inside-code}
```
''',
      );
    });

    test('unescapes Vue braces for Jaspr markdown', () {
      const input = r'''
Paragraph with \{\{ value \}\}
''';

      expect(
        JasprGeneratorBackend.stripVitePressSyntaxForJaspr(input),
        '''
Paragraph with {{ value }}
''',
      );
    });

    test('removes Badge components and TOC markers outside code fences', () {
      const input = '''
[[toc]]

# Example <Badge type="warning" text="deprecated" />

```md
[[toc]]
<Badge type="tip" text="keep" />
```
''';

      expect(
        JasprGeneratorBackend.stripVitePressSyntaxForJaspr(input),
        '''
# Example

```md
[[toc]]
<Badge type="tip" text="keep" />
```
''',
      );
    });
  });

  group('JasprSidebarGenerator', () {
    test('generateGuide emits Dart sidebar data, not VitePress TypeScript', () {
      final generator = JasprSidebarGenerator(JasprPathResolver());
      final output = generator.generateGuide(
        [
          GuideEntry(
            packageName: 'pkg',
            relativePath: 'guide/getting-started.md',
            title: 'Getting Started',
            content: '# Getting Started',
          ),
        ],
        isMultiPackage: false,
      );

      expect(output, contains('const guideSidebarGroups = <SidebarGroup>['));
      expect(
          output,
          contains(
              "SidebarItem(text: 'Getting Started', link: '/guide/getting-started')"));
      expect(output,
          isNot(contains("import type { DefaultTheme } from 'vitepress'")));
      expect(output, isNot(contains('export const guideSidebar')));
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

      final rewritten = JasprGeneratorBackend.rewriteGuideLinksForJaspr(entries);
      expect(
        rewritten.first.content,
        contains('[Configuration](/guide/advanced/configuration)'),
      );
    });

    test('rewrites same-page anchors to Jaspr heading ids', () {
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

      final rewritten = JasprGeneratorBackend.rewriteGuideLinksForJaspr(entries);
      expect(
        rewritten.single.content,
        contains('[Section 5.2](#52-scope-precedence-hierarchy)'),
      );
    });
  });
}
