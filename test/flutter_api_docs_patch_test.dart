import 'package:test/test.dart';

import '../tool/src/flutter_api_docs_patch.dart';

void main() {
  test('patches only the sanity check invocation', () {
    const source = '''
final Iterable<RegExpMatch> versionMatches = RegExp(
  r'^(?<name>dartdoc) (?<version>[^\\s]+)',
  multiLine: true,
).allMatches(versionResults.stdout as String);

final List<String> dartdocArgs = <String>[
  'global',
  'run',
  '--enable-asserts',
  'dartdoc',
];

void _sanityCheckDocs([Platform platform = const LocalPlatform()]) {
  print('checking');
}

/// A subset of all generated doc files for [_sanityCheckDocs].
Future<void> generateDartdoc() async {
    _sanityCheckDocs();
}
''';

    final patched = patchFlutterApiDocsRunnerSource(source);

    expect(
      patched,
      contains(
        r"r'^(?<name>dartdoc(?:_(?:modern|vitepress))?) (?<version>[^\s]+)'",
      ),
    );
    expect(patched, contains("'dartdoc_modern',"));
    expect(patched, contains('// _sanityCheckDocs();'));
    expect(
      patched,
      contains(
        'void _sanityCheckDocs([Platform platform = const LocalPlatform()]) {',
      ),
    );
    expect(
      patched,
      contains(
        '/// A subset of all generated doc files for [_sanityCheckDocs].',
      ),
    );
    expect(
      patched,
      isNot(
        contains(
          'void // _sanityCheckDocs([Platform platform = const LocalPlatform()]) {',
        ),
      ),
    );
  });
}
