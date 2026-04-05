import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:dartdoc_modern/src/generator/core/docs_recipe.dart';
import 'package:test/test.dart';

import 'src/utils.dart';

void main() {
  group('self-docs recipe', () {
    test('overrides guide inputs and excludes Jaspr scaffold libraries', () {
      final packageMetaProvider = testPackageMetaProvider;
      final resourceProvider =
          packageMetaProvider.resourceProvider as MemoryResourceProvider;
      final packageDir = writePackage(
        'dartdoc_modern',
        resourceProvider,
        pubspecContent: '''
name: dartdoc_modern
version: 0.0.1
repository: https://github.com/777genius/dartdoc_modern
''',
      );
      packageDir
          .getChildAssumingFolder('lib')
          .getChildAssumingFolder('resources')
          .getChildAssumingFolder('jaspr')
          .getChildAssumingFolder('lib')
          .getChildAssumingFile('app.dart')
          .writeAsStringSync('void main() {}');
      packageDir
          .getChildAssumingFolder('lib')
          .getChildAssumingFolder('resources')
          .getChildAssumingFolder('jaspr')
          .getChildAssumingFolder('lib')
          .getChildAssumingFolder('components')
          .getChildAssumingFile('docs_header.dart')
          .writeAsStringSync('class DocsHeader {}');

      final context = generatorContextFromArgv([
        '--format',
        'jaspr',
        '--recipe',
        selfDocsRecipeName,
        '--input',
        packageDir.path,
        '--output',
        '/tmp/docs-site',
      ], packageMetaProvider);

      expect(context.recipe, selfDocsRecipeName);
      expect(context.guideDirs, ['docs-site/guide']);
      expect(context.guideExclude, ['api/static-assets/.*']);
      expect(context.exclude, contains('api_symbols'));
      expect(context.exclude, contains('api_sidebar'));
      expect(context.exclude, contains('guide_sidebar'));
      expect(
        context.exclude,
        contains(
          'package:dartdoc_modern/resources/jaspr/lib/generated/api_sidebar.dart',
        ),
      );
      expect(
        context.exclude,
        contains(
          'package:dartdoc_modern/resources/jaspr/lib/generated/guide_sidebar.dart',
        ),
      );
      expect(
        context.exclude,
        contains('package:dartdoc_modern/resources/jaspr/lib/app.dart'),
      );
      expect(
        context.exclude,
        contains(
          'package:dartdoc_modern/resources/jaspr/lib/components/docs_header.dart',
        ),
      );
    });

    test('builds branded home page markdown', () {
      final markdown = buildRecipeHomePageMarkdown(
        selfDocsRecipeName,
        packageName: 'dartdoc_modern',
        repositoryUrl: 'https://github.com/777genius/dartdoc_modern',
      );

      expect(markdown, isNotNull);
      expect(markdown, contains('title: "dartdoc_modern"'));
      expect(markdown, contains('text: Quick Start'));
      expect(
        markdown,
        contains(
          '[VitePress version](https://777genius.github.io/dartdoc_modern/vitepress/)',
        ),
      );
      expect(
        markdown,
        contains(
          '[Jaspr version](https://777genius.github.io/dartdoc_modern/jaspr/)',
        ),
      );
      expect(
        markdown,
        contains('link: https://github.com/777genius/dartdoc_modern'),
      );
    });
  });
}
