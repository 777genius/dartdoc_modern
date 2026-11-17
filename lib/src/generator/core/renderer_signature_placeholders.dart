part of 'api_markdown_renderer.dart';

final class _SignaturePlaceholders {
  final Map<String, String> replacements = <String, String>{};
  int _nextId = 0;

  String token(String prefix, String html, {required String plainText}) {
    final id = _nextId++;
    final baseKey = '${prefix}_$id';
    final targetLength = plainText.length.clamp(baseKey.length, 120);
    final fillerLength = targetLength - baseKey.length;
    final key = fillerLength > 0 ? '$baseKey${'x' * fillerLength}' : baseKey;
    replacements[key] = html;
    return key;
  }
}

String _renderTypePlaceholder(
  ElementType type,
  MarkdownPathResolver paths,
  _SignaturePlaceholders placeholders,
) {
  if (type is DefinedElementType) {
    final url = paths.relativeUrlFor(type.modelElement);
    final token = placeholders.token(
      _signaturePlaceholderPrefixType,
      url != null
          ? '<a href="$url" class="type-link">${_htmlEsc(type.name)}</a>'
          : '<span class="type">${_htmlEsc(type.name)}</span>',
      plainText: type.name,
    );
    final buffer = StringBuffer()..write(token);
    final typeArguments = type.typeArguments.toList();
    if (typeArguments.isNotEmpty) {
      buffer.write('<');
      buffer.write(
        typeArguments
            .map((arg) => _renderTypePlaceholder(arg, paths, placeholders))
            .join(', '),
      );
      buffer.write('>');
    }
    buffer.write(type.nullabilitySuffix);
    return buffer.toString();
  }

  if (type is Callable) {
    final buffer = StringBuffer()
      ..write(_renderTypePlaceholder(type.returnType, paths, placeholders))
      ..write(' Function(')
      ..write(
        _buildPlaceholderCallableParamList(
          type.parameters,
          paths,
          placeholders,
        ),
      )
      ..write(')');
    buffer.write(type.nullabilitySuffix);
    return buffer.toString();
  }

  return placeholders.token(
    _signaturePlaceholderPrefixType,
    '<span class="type">${_htmlEsc(type.nameWithGenericsPlain)}</span>',
    plainText: type.nameWithGenericsPlain,
  );
}

String _buildPlaceholderCallableParamList(
  List<Parameter> parameters,
  MarkdownPathResolver paths,
  _SignaturePlaceholders placeholders,
) {
  if (parameters.isEmpty) return '';

  final parts = <String>[];
  var inOptionalPositional = false;
  var inNamed = false;

  for (final param in parameters) {
    final buffer = StringBuffer();

    if (param.isOptionalPositional && !inOptionalPositional) {
      inOptionalPositional = true;
      buffer.write('[');
    } else if (param.isNamed && !inNamed) {
      inNamed = true;
      buffer.write('{');
    }

    if (param.isRequiredNamed) {
      buffer.write('required ');
    }

    buffer.write(_renderTypePlaceholder(param.modelType, paths, placeholders));
    if (param.name.isNotEmpty) {
      buffer.write(
        ' ${placeholders.token(_signaturePlaceholderPrefixParam, '<span class="param">${_htmlEsc(param.name)}</span>', plainText: param.name)}',
      );
    }

    final defaultValue = param.defaultValue;
    if (defaultValue != null && defaultValue.isNotEmpty) {
      buffer.write(' = ${defaultValue.trim()}');
    }

    parts.add(buffer.toString());
  }

  var result = parts.join(', ');
  if (inOptionalPositional) result += ']';
  if (inNamed) result += '}';
  return result;
}

String _buildPlaceholderParameterSignature(
  List<Parameter> parameters,
  MarkdownPathResolver paths,
  _SignaturePlaceholders placeholders,
) {
  if (parameters.isEmpty) return '()';

  final requiredPositional = <String>[];
  final optionalPositional = <String>[];
  final named = <String>[];

  for (final param in parameters) {
    final buffer = StringBuffer();

    if (param.isRequiredNamed) {
      buffer.write('required ');
    }

    buffer.write(_renderTypePlaceholder(param.modelType, paths, placeholders));
    if (param.name.isNotEmpty) {
      buffer.write(
        ' ${placeholders.token(_signaturePlaceholderPrefixParam, '<span class="param">${_htmlEsc(param.name)}</span>', plainText: param.name)}',
      );
    }

    final defaultValue = param.defaultValue;
    if (defaultValue != null && defaultValue.isNotEmpty) {
      buffer.write(' = ${defaultValue.trim()}');
    }

    if (param.isNamed) {
      named.add(buffer.toString());
    } else if (param.isOptionalPositional) {
      optionalPositional.add(buffer.toString());
    } else {
      requiredPositional.add(buffer.toString());
    }
  }

  final all = <String>[...requiredPositional];
  if (optionalPositional.isNotEmpty) {
    all.add('[${optionalPositional.join(', ')}]');
  } else if (named.isNotEmpty) {
    all.add('{${named.join(', ')}}');
  }

  return '(${all.join(', ')})';
}

String _formatLinkedMemberDeclaration(
  String declaration,
  _SignaturePlaceholders placeholders, {
  required String wrapperClassName,
}) {
  final formattedDeclaration = _formatMemberDeclaration(
    declaration,
    wrapperClassName: wrapperClassName,
  );
  return _replaceSignaturePlaceholders(
    formattedDeclaration,
    placeholders.replacements,
  );
}

String _formatMemberDeclaration(
  String declaration, {
  required String wrapperClassName,
}) {
  final wrapped = 'abstract class $wrapperClassName {\n  $declaration;\n}\n';
  try {
    final formatted = _dartSignatureFormatter.format(wrapped);
    final lines = formatted.split('\n');
    if (lines.length < 3) return declaration;
    final bodyLines = lines.sublist(1, lines.length - 2);
    return bodyLines
        .map((line) => line.startsWith('  ') ? line.substring(2) : line)
        .join('\n')
        .trimRight();
  } on FormatterException {
    return declaration;
  }
}

String _replaceSignaturePlaceholders(
  String formatted,
  Map<String, String> replacements,
) {
  if (replacements.isEmpty) return _renderRawSignatureSegment(formatted);

  final keys = replacements.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(keys.map(RegExp.escape).join('|'));
  final buffer = StringBuffer();
  var lastIndex = 0;

  for (final match in pattern.allMatches(formatted)) {
    if (match.start > lastIndex) {
      buffer.write(
        _renderRawSignatureSegment(formatted.substring(lastIndex, match.start)),
      );
    }
    buffer.write(replacements[match.group(0)!]);
    lastIndex = match.end;
  }

  if (lastIndex < formatted.length) {
    buffer.write(_renderRawSignatureSegment(formatted.substring(lastIndex)));
  }

  return buffer.toString();
}

String _renderRawSignatureSegment(String raw) {
  if (raw.isEmpty) return '';

  final buffer = StringBuffer();
  final tokenPattern = RegExp(
    r'''-?\d+(?:\.\d+)?|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|\b(?:const|factory|required|get|set|Function|true|false|null)\b''',
    multiLine: true,
  );
  var lastIndex = 0;

  for (final match in tokenPattern.allMatches(raw)) {
    if (match.start > lastIndex) {
      buffer.write(_htmlEsc(raw.substring(lastIndex, match.start)));
    }
    final token = match.group(0)!;
    if (token == 'Function') {
      buffer.write('<span class="type">Function</span>');
    } else if (token == 'true' || token == 'false' || token == 'null') {
      buffer.write('<span class="kw">${_htmlEsc(token)}</span>');
    } else if (token == 'const' ||
        token == 'factory' ||
        token == 'required' ||
        token == 'get' ||
        token == 'set') {
      buffer.write('<span class="kw">${_htmlEsc(token)}</span>');
    } else if (token.startsWith('"') || token.startsWith("'")) {
      buffer.write('<span class="str-lit">${_htmlEsc(token)}</span>');
    } else {
      buffer.write('<span class="num-lit">${_htmlEsc(token)}</span>');
    }
    lastIndex = match.end;
  }

  if (lastIndex < raw.length) {
    buffer.write(_htmlEsc(raw.substring(lastIndex)));
  }

  return buffer.toString();
}

/// Builds a linked field/property signature as HTML.
String _buildLinkedFieldSignature(Field field, MarkdownPathResolver paths) {
  final sig = StringBuffer();
  if (field.isConst) {
    sig.write('<span class="kw">const</span> ');
  } else if (field.isFinal) {
    sig.write('<span class="kw">final</span> ');
  }
  if (field.isLate) {
    sig.write('<span class="kw">late</span> ');
  }

  final linkedType = _renderTypeLinked(field.modelType, paths);
  final fnName = '<span class="fn">${_htmlEsc(field.name)}</span>';
  if (field.hasExplicitGetter && !field.hasExplicitSetter) {
    sig.write('$linkedType <span class="kw">get</span> $fnName');
  } else if (field.hasExplicitSetter && !field.hasExplicitGetter) {
    sig.write(
      '<span class="kw">set</span> $fnName($linkedType <span class="param">value</span>)',
    );
  } else if (field.hasExplicitGetter && field.hasExplicitSetter) {
    sig.write('$linkedType <span class="kw">get</span> $fnName');
  } else {
    sig.write('$linkedType $fnName');
  }

  if (field.isConst && field.hasConstantValueForDisplay) {
    sig.write(' = ${_wrapDefaultValue(field.constantValueBase)}');
  }

  return sig.toString();
}

/// Builds a linked top-level property/constant signature as HTML.
String _buildLinkedPropertySignature(
  TopLevelVariable prop,
  MarkdownPathResolver paths,
) {
  final sig = StringBuffer();
  if (prop.isConst) {
    sig.write('<span class="kw">const</span> ');
  } else if (prop.isFinal) {
    sig.write('<span class="kw">final</span> ');
  }
  sig.write(
    '${_renderTypeLinked(prop.modelType, paths)} <span class="fn">${_htmlEsc(prop.name)}</span>',
  );

  if (prop.isConst && prop.hasConstantValueForDisplay) {
    sig.write(' = ${_wrapDefaultValue(prop.constantValueBase)}');
  }

  return sig.toString();
}

/// Renders the documentation body for a member element.
///
/// This handles the full doc, deprecation notice, and inherited-from marker.
/// Post-processes member documentation to fix heading levels and IDs.
///
/// Doc comments may contain H2/H3 headings with explicit `{#id}` anchors.
/// When multiple members on the same page have the same headings (e.g.
/// `## Other resources {#other-resources}`), VitePress fails on duplicate IDs.
///
/// This function:
/// 1. Strips explicit `{#...}` heading IDs.
/// 2. Increases heading depth by 2 levels (## -> ####, ### -> #####) so that
///    headings within member docs nest properly under the H3 member heading.
/// 3. Appends a unique explicit `{#memberAnchor-heading-slug}` ID to each
///    heading, preventing VitePress auto-slug conflicts when multiple members
///    on the same page have identically-named headings.