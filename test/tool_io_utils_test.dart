import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../tool/src/io_utils.dart' as tool_io;

void main() {
  group('tool io utils', () {
    test('copy preserves executable permissions on copied files', () {
      if (Platform.isWindows) {
        return;
      }

      final sourceRoot = Directory.systemTemp.createTempSync('tool-copy-src');
      addTearDown(() => sourceRoot.deleteSync(recursive: true));
      final destinationRoot = Directory.systemTemp.createTempSync(
        'tool-copy-dst',
      );
      addTearDown(() => destinationRoot.deleteSync(recursive: true));

      final sourceFile = File(path.join(sourceRoot.path, 'bin', 'flutter'))
        ..createSync(recursive: true)
        ..writeAsStringSync('#!/usr/bin/env bash\necho ok\n');
      final chmodResult = Process.runSync('chmod', ['755', sourceFile.path]);
      expect(chmodResult.exitCode, 0);

      tool_io.copy(sourceRoot, destinationRoot);

      final copiedFile = File(
        path.join(destinationRoot.path, 'bin', 'flutter'),
      );
      expect(copiedFile.existsSync(), isTrue);
      expect(
        copiedFile.statSync().mode & 0x1FF,
        sourceFile.statSync().mode & 0x1FF,
      );
    });

    test('copy preserves symbolic links', () {
      if (Platform.isWindows) {
        return;
      }

      final sourceRoot = Directory.systemTemp.createTempSync('tool-link-src');
      addTearDown(() => sourceRoot.deleteSync(recursive: true));
      final destinationRoot = Directory.systemTemp.createTempSync(
        'tool-link-dst',
      );
      addTearDown(() => destinationRoot.deleteSync(recursive: true));

      final targetFile = File(path.join(sourceRoot.path, 'real.txt'))
        ..createSync(recursive: true)
        ..writeAsStringSync('hello');
      final link = Link(path.join(sourceRoot.path, 'alias.txt'))
        ..createSync('real.txt');
      expect(link.targetSync(), 'real.txt');

      tool_io.copy(sourceRoot, destinationRoot);

      final copiedLink = Link(path.join(destinationRoot.path, 'alias.txt'));
      expect(copiedLink.existsSync(), isTrue);
      expect(copiedLink.targetSync(), 'real.txt');
      expect(
        File(path.join(destinationRoot.path, 'real.txt')).readAsStringSync(),
        'hello',
      );
      expect(targetFile.existsSync(), isTrue);
    });
  });
}
