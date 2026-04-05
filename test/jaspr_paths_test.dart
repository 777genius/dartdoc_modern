import 'package:dartdoc_modern/src/generator/jaspr/paths.dart';
import 'package:dartdoc_modern/src/package_meta.dart';
import 'package:test/test.dart';

import 'src/utils.dart';

void main() {
  group('JasprPathResolver.relativeUrlFor', () {
    test('uses root-aware links for API pages', () async {
      final packageGraph = await bootBasicPackage(
        'testing/test_package_with_docs',
        pubPackageMetaProvider,
      );
      final library = packageGraph.defaultPackage.libraries.singleWhere(
        (library) => library.name == 'test_package_with_docs',
      );
      final greeter = library.classesAndExceptions.singleWhere(
        (container) => container.name == 'Greeter',
      );
      final formatter = library.classesAndExceptions.singleWhere(
        (container) => container.name == 'MessageFormatter',
      );
      final result = library.classesAndExceptions.singleWhere(
        (container) => container.name == 'GreetingResult',
      );

      final paths = JasprPathResolver()..initFromPackageGraph(packageGraph);

      paths.currentPageUrl = paths.urlFor(greeter);
      expect(
        paths.relativeUrlFor(formatter),
        '/api/test_package_with_docs/MessageFormatter',
      );
      expect(
        paths.relativeUrlFor(result),
        '/api/test_package_with_docs/GreetingResult',
      );

      paths.currentPageUrl = paths.urlFor(library);
      expect(
        paths.relativeUrlFor(greeter),
        '/api/test_package_with_docs/Greeter',
      );
    });
  });
}
