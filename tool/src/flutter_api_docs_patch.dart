// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

String patchFlutterApiDocsRunnerSource(String contents) {
  var patched = _replaceRequired(
    contents,
    r"r'^(?<name>dartdoc) (?<version>[^\s]+)'",
    r"r'^(?<name>dartdoc(?:_(?:modern|vitepress))?) (?<version>[^\s]+)'",
    description: 'dartdoc version matcher',
  );
  patched = _replaceRequired(
    patched,
    "'dartdoc',",
    "'dartdoc_modern',",
    description: 'dartdoc executable name',
  );
  patched = _replaceRequired(
    patched,
    '    _sanityCheckDocs();',
    '    // Disabled for dartdoc_modern: this canary expects upstream HTML.\n'
        '    // _sanityCheckDocs();',
    description: 'sanity check invocation',
  );
  patched = _replaceRequired(
    patched,
    "    checkForUnresolvedDirectives(publishRoot.childDirectory('flutter'));",
    '    // Disabled for dartdoc_modern: this checker expects upstream HTML.\n'
        "    // checkForUnresolvedDirectives(publishRoot.childDirectory('flutter'));",
    description: 'unresolved directives check invocation',
  );
  patched = _replaceRequired(
    patched,
    '    _createIndexAndCleanup();',
    '    // Disabled for dartdoc_modern: this post-processing expects HTML output.\n'
        '    // _createIndexAndCleanup();',
    description: 'index and cleanup invocation',
  );
  return patched;
}

String _replaceRequired(
  String source,
  String from,
  String to, {
  required String description,
}) {
  final replaced = source.replaceFirst(from, to);
  if (identical(replaced, source) || replaced == source) {
    throw StateError(
      'Failed to patch Flutter API docs runner: missing $description.',
    );
  }
  return replaced;
}
