// ignore_for_file: avoid_relative_lib_imports

import 'package:jaspr_content/src/page.dart';
import 'package:jaspr_content/src/route_loader/route_loader.dart';
import 'package:jaspr_content/src/template_engine/template_engine.dart';
import 'package:jaspr_router/jaspr_router.dart' show RouteBase;
import 'package:test/test.dart';

import '../lib/resources/jaspr/lib/template_engine/docs_template_engine.dart';

void main() {
  group('DocsTemplateEngine', () {
    test('rewrites callout containers to Jaspr custom components', () async {
      final page = _page('''
:::tip Quick Start
Use Greeter first.
:::

:::warning Caveat
Watch for retries.
:::
''');

      await DocsTemplateEngine().render(page, const []);

      expect(
        page.content,
        contains(
          '<Success>\n\n**Quick Start**\n\nUse Greeter first.\n\n</Success>',
        ),
      );
      expect(
        page.content,
        contains('<Warning>\n\n**Caveat**\n\nWatch for retries.\n\n</Warning>'),
      );
    });

    test('preserves details containers as details html', () async {
      final page = _page('''
:::details Suggested path
Read the guide.
:::
''');

      await DocsTemplateEngine().render(page, const []);

      expect(
        page.content,
        contains(
          '<details>\n<summary>Suggested path</summary>\n\nRead the guide.\n\n</details>',
        ),
      );
    });

    test('does not rewrite containers inside code fences', () async {
      final page = _page('''
```md
:::tip Quick Start
leave me alone
:::
```
''');

      await DocsTemplateEngine().render(page, const []);

      expect(page.content, contains(':::tip Quick Start'));
      expect(page.content, isNot(contains('<Success>')));
    });
  });
}

Page _page(String content) {
  return Page(
    path: 'guide/example.md',
    url: '/guide/example',
    content: content,
    config: const PageConfig(templateEngine: _NoopTemplateEngine()),
    loader: _FakeRouteLoader(),
  );
}

class _NoopTemplateEngine implements TemplateEngine {
  const _NoopTemplateEngine();

  @override
  Future<void> render(Page page, List<Page> pages) async {}
}

class _FakeRouteLoader extends RouteLoader {
  _FakeRouteLoader();

  @override
  Future<List<RouteBase>> loadRoutes(
    ConfigResolver resolver,
    bool eager,
  ) async {
    return const [];
  }

  @override
  Future<String> readPartial(String path, Page page) async => '';

  @override
  String readPartialSync(String path, Page page) => '';

  @override
  void invalidatePage(Page page) {}
}
