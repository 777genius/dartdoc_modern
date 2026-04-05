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
        'https://777genius.github.io/dartdoc_modern/jaspr/guide/jaspr-vs-vitepress?tab=usage#switch',
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
  });
}
