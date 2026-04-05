import 'package:dartdoc_modern/resources/jaspr/lib/project_version_routes.dart';
import 'package:test/test.dart';

void main() {
  group('project version routes', () {
    test('maps Jaspr library overview to VitePress library overview', () {
      expect(
        projectVitePressUrlForRoute('/api/dartdoc/library'),
        'https://777genius.github.io/dartdoc_modern/vitepress/api/dartdoc/',
      );
    });

    test('maps VitePress library overview to Jaspr library overview', () {
      expect(
        projectJasprUrlForRoute('/api/dartdoc/'),
        'https://777genius.github.io/dartdoc_modern/jaspr/api/dartdoc/library',
      );
    });

    test('keeps member page routes stable across versions', () {
      expect(
        projectVitePressUrlForRoute('/api/dartdoc/initJasprGenerator'),
        'https://777genius.github.io/dartdoc_modern/vitepress/api/dartdoc/initJasprGenerator',
      );
      expect(
        projectJasprUrlForRoute('/api/dartdoc/initJasprGenerator'),
        'https://777genius.github.io/dartdoc_modern/jaspr/api/dartdoc/initJasprGenerator',
      );
      expect(
        projectJasprUrlForRoute('/api/dartdoc/CategoryDefinition.html'),
        'https://777genius.github.io/dartdoc_modern/jaspr/api/dartdoc/CategoryDefinition',
      );
    });

    test('preserves guide routes with query and hash', () {
      expect(
        projectVitePressUrlForRoute(
          '/guide/jaspr-vs-vitepress?tab=usage#switch',
        ),
        'https://777genius.github.io/dartdoc_modern/vitepress/guide/jaspr-vs-vitepress?tab=usage#switch',
      );
      expect(
        projectJasprUrlForRoute('/guide/jaspr-vs-vitepress?tab=usage#switch'),
        'https://777genius.github.io/dartdoc_modern/jaspr/guide/jaspr-vs-vitepress.html?tab=usage#switch',
      );
    });

    test('normalizes guide deep links for Jaspr static hosting', () {
      expect(
        projectJasprUrlForRoute('/guide/jaspr-deployment'),
        'https://777genius.github.io/dartdoc_modern/jaspr/guide/jaspr-deployment.html',
      );
      expect(
        projectJasprUrlForRoute('/guide/jaspr-deployment.html'),
        'https://777genius.github.io/dartdoc_modern/jaspr/guide/jaspr-deployment.html',
      );
      expect(
        projectVitePressUrlForRoute('/guide/jaspr-deployment.html'),
        'https://777genius.github.io/dartdoc_modern/vitepress/guide/jaspr-deployment.html',
      );
    });

    test('normalizes package overview routes', () {
      expect(
        projectVitePressUrlForRoute('/api'),
        'https://777genius.github.io/dartdoc_modern/vitepress/api/',
      );
      expect(
        projectJasprUrlForRoute('/api/'),
        'https://777genius.github.io/dartdoc_modern/jaspr/api',
      );
    });

    test('falls back to shared API root for VitePress-only library pages', () {
      expect(
        projectJasprUrlForRoute(
          '/api/resources_jaspr_lib_components_docs_disclosure_runtime/',
        ),
        'https://777genius.github.io/dartdoc_modern/jaspr/api',
      );
      expect(
        projectJasprUrlForRoute(
          '/api/resources_jaspr_lib_components_docs_disclosure_runtime/DocsDisclosureRuntime',
        ),
        'https://777genius.github.io/dartdoc_modern/jaspr/api',
      );
    });
  });
}
