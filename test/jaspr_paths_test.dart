import 'package:dartdoc_vitepress/src/generator/jaspr/paths.dart';
import 'package:dartdoc_vitepress/src/package_meta.dart';
import 'package:test/test.dart';

import 'src/utils.dart';

void main() {
  group('JasprPathResolver.relativeUrlFor', () {
    test('uses route-relative links for sibling API pages', () async {
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
      expect(paths.relativeUrlFor(formatter), '../MessageFormatter');
      expect(paths.relativeUrlFor(result), '../GreetingResult');

      paths.currentPageUrl = paths.urlFor(library);
      expect(paths.relativeUrlFor(greeter), '../Greeter');
    });
  });
}
