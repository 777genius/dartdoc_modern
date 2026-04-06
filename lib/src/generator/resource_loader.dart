// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Make it possible to load resources from the dartdoc code repository.
///
/// Supports both JIT (`dart run`) and AOT (`dart compile exe`) execution.
/// In JIT mode, `Isolate.resolvePackageUri` resolves `package:` URIs directly.
/// In AOT mode, the resolver falls back to reading
/// `.dart_tool/package_config.json` from the source tree to locate the package
/// root, or uses the `DARTDOC_MODERN_ROOT` environment variable.
library;

import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate' show Isolate;

import 'package:analyzer/file_system/file_system.dart';
import 'package:meta/meta.dart';

extension ResourceLoader on ResourceProvider {
  Future<Folder> getResourceFolder(String path) async {
    var uri = await resolveResourceUri(Uri.parse(path));
    return getFolder(uri.toFilePath());
  }

  /// Resolves a `package:` or relative URI to a `file:` URI.
  ///
  /// In JIT mode, delegates to `Isolate.resolvePackageUri`.
  /// In AOT mode (when `Isolate.resolvePackageUri` returns `null`), falls back
  /// to manual package config resolution.
  @visibleForTesting
  Future<Uri> resolveResourceUri(Uri uri) async {
    if (uri.scheme == 'package') {
      // Try the standard JIT resolution first.
      var resolvedUri = await Isolate.resolvePackageUri(uri);
      if (resolvedUri != null) return resolvedUri;

      // AOT fallback: resolve manually from package_config.json or env var.
      return _resolvePackageUriAot(uri);
    } else {
      return Uri.base.resolveUri(uri);
    }
  }
}

/// Resolves a `package:` URI by reading the package_config.json or using the
/// `DARTDOC_MODERN_ROOT` environment variable.
///
/// A `package:foo/path/to/file` URI maps to `<packageRoot>/lib/path/to/file`.
Uri _resolvePackageUriAot(Uri packageUri) {
  assert(packageUri.scheme == 'package');

  final pathSegments = packageUri.pathSegments;
  if (pathSegments.isEmpty) {
    throw ArgumentError.value(packageUri, 'uri', 'Empty package URI');
  }

  final packageName = pathSegments.first;
  final relativeWithinLib = pathSegments.skip(1).join('/');

  // Strategy 1: DARTDOC_MODERN_ROOT environment variable.
  // Allows explicit override, useful for CI/CD.
  final envRoot = io.Platform.environment['DARTDOC_MODERN_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) {
    final resourcePath = '$envRoot/lib/$relativeWithinLib';
    final resourceUri = Uri.file(resourcePath);
    if (io.File.fromUri(resourceUri).existsSync() ||
        _isDirectory(resourcePath)) {
      return resourceUri;
    }
  }

  // Strategy 2: Find package_config.json relative to the executable.
  // When `dart compile exe bin/tool.dart -o bin/tool`, the executable
  // is often near the source tree.
  final executableDir = _parentDir(io.Platform.resolvedExecutable);
  for (final candidate in [
    // Binary in bin/ -> package root is parent
    _parentDir(executableDir),
    // Binary in the package root itself
    executableDir,
    // Binary somewhere else, but CWD is the package root
    // (common for `dart compile exe ... -o /tmp/tool && cd pkg && /tmp/tool`)
    null, // will use Platform.environment['PWD'] below
  ]) {
    final root = candidate ?? (io.Platform.environment['PWD'] ?? '.');
    final configPath = '$root/.dart_tool/package_config.json';
    final configFile = io.File(configPath);
    if (!configFile.existsSync()) continue;

    final packageRoot = _findPackageRoot(configFile, packageName);
    if (packageRoot == null) continue;

    final resourcePath = '$packageRoot/lib/$relativeWithinLib';
    final resourceUri = Uri.file(resourcePath);
    if (io.File.fromUri(resourceUri).existsSync() ||
        _isDirectory(resourcePath)) {
      return resourceUri;
    }
  }

  throw ArgumentError.value(
    packageUri,
    'uri',
    'Could not resolve package URI in AOT mode. '
    'Set DARTDOC_MODERN_ROOT to the dartdoc-modern source directory, '
    'or run from within the source tree.',
  );
}

/// Reads a `.dart_tool/package_config.json` and returns the root path for
/// [packageName], or `null` if not found.
String? _findPackageRoot(io.File configFile, String packageName) {
  try {
    final content = configFile.readAsStringSync();
    final config = jsonDecode(content) as Map<String, dynamic>;
    final packages = config['packages'] as List<dynamic>?;
    if (packages == null) return null;

    final configDir = _parentDir(configFile.path);

    for (final pkg in packages) {
      if (pkg is! Map<String, dynamic>) continue;
      if (pkg['name'] != packageName) continue;

      final rootUri = pkg['rootUri'] as String?;
      if (rootUri == null) continue;

      // rootUri is relative to the package_config.json directory.
      if (rootUri.startsWith('file://')) {
        return Uri.parse(rootUri).toFilePath();
      }
      // Relative URI (e.g., "../" for the project itself, or a pub cache path).
      final resolved = Uri.parse('$configDir/').resolve(rootUri);
      return resolved.toFilePath().replaceAll(RegExp(r'/$'), '');
    }
  } on Object {
    // Malformed config, skip.
  }
  return null;
}

String _parentDir(String path) {
  final sep = io.Platform.pathSeparator;
  final trimmed = path.endsWith(sep) ? path.substring(0, path.length - 1) : path;
  final lastSep = trimmed.lastIndexOf(sep);
  return lastSep > 0 ? trimmed.substring(0, lastSep) : trimmed;
}

bool _isDirectory(String path) {
  try {
    return io.Directory(path).existsSync();
  } on Object {
    return false;
  }
}
