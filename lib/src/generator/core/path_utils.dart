// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Format-agnostic path and name sanitization utilities.
///
/// These functions are shared across all output format backends (VitePress,
/// Jaspr, etc.). They must not emit any format-specific syntax.
library;

import 'package:dartdoc_vitepress/src/model/model.dart';

/// Matches characters not allowed in file names across common file systems.
final unsafeFileChars = RegExp(r'[:<>|?*"/\\]');

/// Collapses runs of multiple hyphens into one.
final multiDash = RegExp(r'-+');

/// Removes leading or trailing hyphens.
final leadTrailDash = RegExp(r'^-|-$');

/// Matches any non-alphanumeric character.
final nonAlphanumeric = RegExp(r'[^a-zA-Z0-9]');

/// Replaces characters that are invalid or problematic on common file
/// systems with hyphens, then collapses runs of hyphens.
String sanitizeFileName(String name) {
  // Strip generic type parameters first (e.g., `Foo<Bar>` -> `Foo`).
  final angleBracketIndex = name.indexOf('<');
  if (angleBracketIndex != -1) {
    name = name.substring(0, angleBracketIndex);
  }
  // Replace chars problematic on Windows/macOS/Linux: : < > | ? * " / \
  return name
      .replaceAll(unsafeFileChars, '-')
      .replaceAll(multiDash, '-')
      .replaceAll(leadTrailDash, '');
}

/// Strips generic type parameters from a name.
///
/// `get<T>` -> `get`
/// `Map<String, int>` -> `Map`
/// `SimpleBinder` -> `SimpleBinder` (unchanged)
String stripGenerics(String name) {
  final angleBracketIndex = name.indexOf('<');
  if (angleBracketIndex == -1) return name;
  return name.substring(0, angleBracketIndex);
}

/// Sanitizes a string for use as an anchor ID.
///
/// Replaces non-alphanumeric characters with hyphens and lowercases.
String sanitizeAnchor(String value) {
  return value
      .replaceAll(nonAlphanumeric, '-')
      .replaceAll(multiDash, '-')
      .replaceAll(leadTrailDash, '')
      .toLowerCase();
}

/// Normalizes dots to hyphens in SDK-style library directory names.
///
/// Only affects names starting with `dart.` (SDK namespace separators like
/// `dart.dom.svg` -> `dart-dom-svg`). Non-SDK library names (e.g.
/// `class_modifiers.dart`) are returned unchanged.
String normalizeDots(String dirName) {
  if (dirName.startsWith('dart.')) {
    return dirName.replaceAll('.', '-');
  }
  return dirName;
}

final _internalSdkDirPattern = RegExp(r'^(dart\.[a-z_.]+)(/|$)');

/// Normalizes internal SDK library directory names in a path.
///
/// Rewrites the first path segment when it matches `dart.xxx`:
/// - `dart.dom.xxx/...` -> `dart-xxx/...` (strip `.dom.` prefix)
/// - `dart._xxx/...` -> returns empty string (private SDK libraries have no
///   generated pages; the caller should render as inline code)
/// - `dart.xxx/...` -> `dart-xxx/...` (replace first `.` with `-`)
String normalizeSdkLibraryPath(String path) {
  final match = _internalSdkDirPattern.firstMatch(path);
  if (match == null) return path;

  final internalDir = match.group(1)!;
  final hadSeparator = match.group(2) == '/';
  final rest = path.substring(match.end);

  if (internalDir.startsWith('dart._')) return '';

  String canonicalDir;
  if (internalDir.startsWith('dart.dom.')) {
    canonicalDir = 'dart-${internalDir.substring('dart.dom.'.length)}';
  } else {
    canonicalDir = 'dart-${internalDir.substring('dart.'.length)}';
  }

  if (rest.isNotEmpty) return '$canonicalDir/$rest';
  if (hadSeparator) return '$canonicalDir/';
  return canonicalDir;
}

/// Returns `true` if the library is a dot-prefixed SDK duplicate that has a
/// canonical colon-prefixed counterpart (e.g. `dart.io` -> `dart:io`).
///
/// These internal library objects are created by the Dart SDK analyzer alongside
/// the canonical versions. They contain no unique content and should be
/// filtered out to avoid duplicate sidebar entries and broken paths.
bool isDuplicateSdkLibrary(Library lib, Iterable<Library> allLibraries) {
  final name = lib.name;

  // Canonical libraries (containing `:`) are never duplicates.
  if (!name.contains('.') || name.contains(':')) return false;

  // Only handle `dart.xxx` prefixed names.
  if (!name.startsWith('dart.')) return false;

  // Build the set of canonical library names for fast lookup.
  final canonicalNames = <String>{
    for (final l in allLibraries)
      if (l.name.contains(':')) l.name,
  };

  // Heuristic 1: direct mapping `dart.xxx` -> `dart:xxx`.
  final directCanonical = 'dart:${name.substring('dart.'.length)}';
  if (canonicalNames.contains(directCanonical)) return true;

  // Heuristic 2: `dart.dom.xxx` -> `dart:xxx` (strip `.dom.`).
  if (name.startsWith('dart.dom.')) {
    final domCanonical = 'dart:${name.substring('dart.dom.'.length)}';
    if (canonicalNames.contains(domCanonical)) return true;
  }

  return false;
}

/// Returns `true` if the library is an internal SDK or runtime library
/// that should not appear in public API documentation.
bool isInternalSdkLibrary(Library lib) {
  final name = lib.name;
  // Private libraries (Dart convention: leading underscore).
  if (name.startsWith('_')) return true;
  // Private sub-libraries (e.g., dart._http, dart2js._js_primitives).
  if (name.contains('._')) return true;
  // Known SDK/compiler internal libraries without underscore prefix.
  const internalNames = {
    'rti',
    'vmservice_io',
    'metadata',
    'nativewrappers',
    'html_common',
    'dart2js_runtime_metrics',
  };
  if (internalNames.contains(name)) return true;
  return false;
}
