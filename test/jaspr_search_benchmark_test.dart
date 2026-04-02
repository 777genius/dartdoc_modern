import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'benchmark search matches non-Latin queries with Unicode normalization',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'jaspr_benchmark_test.',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final searchIndex = File('${tempDir.path}/search_index.json');
      searchIndex.writeAsStringSync(
        jsonEncode({
          'version': 2,
          'entryCount': 1,
          'entries': [
            [
              'guide',
              'Пример',
              '/guide/primer',
              null,
              'Краткое описание.',
              'Пример документации для Unicode-поиска.',
            ],
          ],
        }),
      );

      final result = Process.runSync(
        Platform.resolvedExecutable,
        ['run', 'tool/jaspr_search_benchmark.dart', searchIndex.path, 'Пример'],
        workingDirectory: Directory.current.path,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('query: Пример'));
      expect(result.stdout, contains('[guide] Пример -> /guide/primer'));
      expect(result.stdout, isNot(contains('no_results')));
    },
  );

  test(
    'benchmark prefers framework generic titles for common short queries',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'jaspr_benchmark_rank.',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final searchIndex = File('${tempDir.path}/search_index.json');
      searchIndex.writeAsStringSync(
        jsonEncode({
          'version': 2,
          'entryCount': 3,
          'entries': [
            [
              'api',
              'State',
              '/api/package-test_api_hooks_testing/State',
              null,
              '',
              '',
            ],
            [
              'api',
              'State<T extends StatefulWidget>',
              '/api/widgets/State',
              null,
              '',
              '',
            ],
            [
              'api',
              'state',
              '/api/package-headless_foundation_state',
              null,
              '',
              '',
            ],
          ],
        }),
      );

      final result = Process.runSync(
        Platform.resolvedExecutable,
        ['run', 'tool/jaspr_search_benchmark.dart', searchIndex.path, 'State'],
        workingDirectory: Directory.current.path,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final lines = const LineSplitter()
          .convert(result.stdout as String)
          .where((line) => line.startsWith('  - '))
          .toList();
      expect(lines, isNotEmpty);
      expect(lines.first, contains('/api/widgets/State'));
    },
  );

  test(
    'benchmark prefers concise framework context types over long suffix matches',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'jaspr_benchmark_context.',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final searchIndex = File('${tempDir.path}/search_index.json');
      searchIndex.writeAsStringSync(
        jsonEncode({
          'version': 2,
          'entryCount': 4,
          'entries': [
            [
              'api',
              'DisposableBuildContext<T extends State<StatefulWidget>>',
              '/api/widgets/DisposableBuildContext',
              null,
              '',
              '',
            ],
            [
              'api',
              'ScrollPositionWithSingleContext',
              '/api/widgets/ScrollPositionWithSingleContext',
              null,
              '',
              '',
            ],
            ['api', 'BuildContext', '/api/widgets/BuildContext', null, '', ''],
            ['api', 'ClipContext', '/api/painting/ClipContext', null, '', ''],
          ],
        }),
      );

      final result = Process.runSync(
        Platform.resolvedExecutable,
        [
          'run',
          'tool/jaspr_search_benchmark.dart',
          searchIndex.path,
          'Context',
        ],
        workingDirectory: Directory.current.path,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final lines = const LineSplitter()
          .convert(result.stdout as String)
          .where((line) => line.startsWith('  - '))
          .toList();
      expect(lines, isNotEmpty);
      expect(lines.first, contains('/api/widgets/BuildContext'));
    },
  );

  test('benchmark dedupes exact page hits ahead of same-page member noise', () {
    final tempDir = Directory.systemTemp.createTempSync(
      'jaspr_benchmark_dedupe.',
    );
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final searchIndex = File('${tempDir.path}/search_index.json');
    searchIndex.writeAsStringSync(
      jsonEncode({
        'version': 2,
        'entryCount': 4,
        'entries': [
          ['api', 'BuildContext', '/api/widgets/BuildContext', null, '', ''],
          [
            'api',
            'BuildContext',
            '/api/widgets/BuildContext#buildcontext',
            'BuildContext()',
            '',
            '',
          ],
          [
            'api',
            'BuildContext',
            '/api/widgets/BuildContext#nosuchmethod',
            'noSuchMethod()',
            '',
            '',
          ],
          [
            'api',
            'BuildContextualThing',
            '/api/widgets/BuildContextualThing',
            null,
            '',
            '',
          ],
        ],
      }),
    );

    final result = Process.runSync(
      Platform.resolvedExecutable,
      [
        'run',
        'tool/jaspr_search_benchmark.dart',
        searchIndex.path,
        'BuildContext',
      ],
      workingDirectory: Directory.current.path,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final lines = const LineSplitter()
        .convert(result.stdout as String)
        .where((line) => line.startsWith('  - '))
        .toList();
    expect(lines, isNotEmpty);
    expect(lines.first, contains('/api/widgets/BuildContext'));
    expect(
      lines.where((line) => line.contains('/api/widgets/BuildContext#')).length,
      lessThanOrEqualTo(1),
    );
  });
}
