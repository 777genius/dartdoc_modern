// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Pure functions that render dartdoc model objects into VitePress-compatible
/// markdown strings.
///
/// All functions use [StringBuffer] to build markdown. They depend on
/// [MarkdownPathResolver] for link/path computation and
/// [MarkdownDocProcessor] for documentation processing.
library;

import 'package:dart_style/dart_style.dart';
import 'package:dartdoc_modern/src/comment_references/parser.dart'
    show operatorNames;
import 'package:dartdoc_modern/src/element_type.dart';
import 'package:dartdoc_modern/src/generator/core/markdown_docs.dart';
import 'package:dartdoc_modern/src/generator/core/markdown_paths.dart';
import 'package:dartdoc_modern/src/model/attribute.dart' show Attribute;
import 'package:dartdoc_modern/src/model/container_modifiers.dart';
import 'package:dartdoc_modern/src/model/model.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' show parseFragment;
import 'package:meta/meta.dart';

export 'package:dartdoc_modern/src/generator/core/markdown_paths.dart'
    show isDuplicateSdkLibrary, isInternalSdkLibrary;

part 'renderer_names_and_page_builder.dart';
part 'renderer_shared_helpers.dart';
part 'renderer_linked_signatures.dart';
part 'renderer_signature_placeholders.dart';
part 'renderer_member_docs.dart';
part 'renderer_member_sections.dart';
part 'renderer_pages_packages.dart';
part 'renderer_pages_others.dart';

final _dartSignatureFormatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);
