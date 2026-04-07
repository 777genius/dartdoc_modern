// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Utilities copied out of `package:grinder/grinder_files.dart`.
library;

import 'dart:io';

final String _sep = Platform.pathSeparator;

/// Copies the given [entity] to the [destinationDir].
void copy(FileSystemEntity entity, Directory destinationDir) {
  print('copying ${entity.path} to ${destinationDir.path}');
  return _copyImpl(entity, destinationDir);
}

void _copyImpl(FileSystemEntity? entity, Directory destDir) {
  final type = FileSystemEntity.typeSync(
    entity?.path ?? '',
    followLinks: false,
  );
  switch (type) {
    case FileSystemEntityType.directory:
      final directory = Directory(entity!.path);
      for (final child in directory.listSync(followLinks: false)) {
        final name = fileName(child);
        final childType = FileSystemEntity.typeSync(
          child.path,
          followLinks: false,
        );
        if (childType == FileSystemEntityType.directory) {
          _copyImpl(child, joinDir(destDir, [name]));
        } else {
          _copyImpl(child, destDir);
        }
      }
      return;
    case FileSystemEntityType.file:
      final file = File(entity!.path);
      final destFile = joinFile(destDir, [fileName(file)]);

      if (!destFile.existsSync() ||
          file.lastModifiedSync() != destFile.lastModifiedSync()) {
        destDir.createSync(recursive: true);
        file.copySync(destFile.path);
        _copyMetadata(file, destFile.path);
      }
      return;
    case FileSystemEntityType.link:
      final link = Link(entity!.path);
      final destLink = Link(joinFile(destDir, [fileName(link)]).path);
      destDir.createSync(recursive: true);
      if (destLink.existsSync()) {
        destLink.deleteSync();
      }
      if (Platform.isWindows) {
        _copyImpl(
          FileSystemEntity.typeSync(link.path) == FileSystemEntityType.directory
              ? Directory(link.resolveSymbolicLinksSync())
              : File(link.resolveSymbolicLinksSync()),
          destDir,
        );
      } else {
        destLink.createSync(link.targetSync());
      }
      return;
    case FileSystemEntityType.notFound:
      throw StateError('unexpected type: ${entity.runtimeType}');
    case FileSystemEntityType.pipe:
    case FileSystemEntityType.unixDomainSock:
      throw StateError('unsupported filesystem entity type: $type');
  }
}

void _copyMetadata(File source, String destinationPath) {
  final destination = File(destinationPath);
  destination.setLastModifiedSync(source.lastModifiedSync());
  if (Platform.isWindows) return;
  final sourceMode = source.statSync().mode & 0x1FF;
  final destinationMode = destination.statSync().mode & 0x1FF;
  if (sourceMode == destinationMode) {
    return;
  }
  final modeString = sourceMode.toRadixString(8).padLeft(3, '0');
  final result = Process.runSync('chmod', [modeString, destination.path]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'chmod',
      [modeString, destination.path],
      result.stderr?.toString() ?? '',
      result.exitCode,
    );
  }
}

/// Return the last segment of the file path.
String fileName(FileSystemEntity entity) {
  final name = entity.path;
  final index = name.lastIndexOf(_sep);
  return (index != -1 ? name.substring(index + 1) : name);
}

File joinFile(Directory dir, List<String> files) {
  final pathFragment = files.join(_sep);
  return File('${dir.path}$_sep$pathFragment');
}

Directory joinDir(Directory dir, List<String> files) {
  final pathFragment = files.join(_sep);
  return Directory('${dir.path}$_sep$pathFragment');
}
