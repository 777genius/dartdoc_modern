// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show stderr;

import 'dartdoc_modern.dart' as modern;

/// Legacy compatibility entrypoint for the old executable name.
void main(List<String> arguments) {
  stderr.writeln(
    'dartdoc_vitepress has been renamed to dartdoc_modern. '
    'The legacy command still works for compatibility.',
  );
  modern.main(arguments);
}
