part of 'api_markdown_renderer.dart';

// ---------------------------------------------------------------------------
// Linked rendering helpers (HTML with clickable type links).
// ---------------------------------------------------------------------------

/// Renders an [ElementType] as HTML with `<a>` links for locally documented
/// types. Types without a local page (SDK types, type parameters, void,
/// dynamic, Never) render as plain HTML-escaped text — no broken links.
String _renderTypeLinked(ElementType type, MarkdownPathResolver paths) {
  // DefinedElementType (includes ParameterizedElementType, TypeParameterElementType)
  if (type is DefinedElementType) {
    final url = paths.relativeUrlFor(type.modelElement);
    final name = _htmlEsc(type.name);
    final buf = StringBuffer();

    // Type name — link if we have a page, styled span otherwise
    buf.write(
      url != null
          ? '<a href="$url" class="type-link">$name</a>'
          : '<span class="type">$name</span>',
    );

    // Type arguments (recursive)
    final args = type.typeArguments.toList();
    if (args.isNotEmpty) {
      buf.write('&lt;');
      buf.write(args.map((a) => _renderTypeLinked(a, paths)).join(', '));
      buf.write('&gt;');
    }

    buf.write(_htmlEsc(type.nullabilitySuffix));
    return buf.toString();
  }

  // Callable (Function types): ReturnType Function(params)
  if (type is Callable) {
    final buf = StringBuffer();
    buf.write(_renderTypeLinked(type.returnType, paths));
    buf.write(' <span class="type">Function</span>(');
    buf.write(_buildLinkedCallableParamList(type.parameters, paths));
    buf.write(')');
    buf.write(_htmlEsc(type.nullabilitySuffix));
    return buf.toString();
  }

  // UndefinedElementType (void, dynamic, Never) — styled as type
  return '<span class="type">${_htmlEsc(type.nameWithGenericsPlain)}</span>';
}

/// Wraps a default value in an appropriate syntax-highlighting span.
///
/// Numeric literals → `.num-lit`, string literals → `.str-lit`,
/// `true`/`false`/`null` → `.kw`, everything else → plain escaped text.
String _wrapDefaultValue(String value) {
  final trimmed = value.trim();
  final escaped = _htmlEsc(trimmed);

  // Numeric literal (int or double, possibly negative)
  if (RegExp(r'^-?\d').hasMatch(trimmed)) {
    return '<span class="num-lit">$escaped</span>';
  }
  // String literal (single/double/raw/triple-quoted)
  if (RegExp(r'''^r?['"]''').hasMatch(trimmed)) {
    return '<span class="str-lit">$escaped</span>';
  }
  // Boolean / null keywords
  if (trimmed == 'true' || trimmed == 'false' || trimmed == 'null') {
    return '<span class="kw">$escaped</span>';
  }
  // Constant references, const expressions — plain text
  return escaped;
}

/// Builds the inner parameter list for a callable type with linked types.
String _buildLinkedCallableParamList(
  List<Parameter> parameters,
  MarkdownPathResolver paths,
) {
  if (parameters.isEmpty) return '';

  final parts = <String>[];
  var inOptionalPositional = false;
  var inNamed = false;

  for (final param in parameters) {
    final buf = StringBuffer();

    if (param.isOptionalPositional && !inOptionalPositional) {
      inOptionalPositional = true;
      buf.write('[');
    } else if (param.isNamed && !inNamed) {
      inNamed = true;
      buf.write('{');
    }

    if (param.isRequiredNamed) {
      buf.write('<span class="kw">required</span> ');
    }

    buf.write(_renderTypeLinked(param.modelType, paths));
    if (param.name.isNotEmpty) {
      buf.write(' <span class="param">${_htmlEsc(param.name)}</span>');
    }

    final defaultValue = param.defaultValue;
    if (defaultValue != null && defaultValue.isNotEmpty) {
      buf.write(' = ${_wrapDefaultValue(defaultValue)}');
    }

    parts.add(buf.toString());
  }

  var result = parts.join(', ');
  if (inOptionalPositional) result += ']';
  if (inNamed) result += '}';
  return result;
}

/// Builds a linked parameter signature string for an element.
///
/// When [prefixLength] is provided, the total signature length is checked
/// against an 80-column threshold. If the single-line version exceeds the
/// limit, parameters are formatted in tall style (one per line, 2-space
/// indent, trailing commas) following `dart format` conventions.
String _buildLinkedParameterSignature(
  List<Parameter> parameters,
  MarkdownPathResolver paths, {
  int prefixLength = 0,
}) {
  if (parameters.isEmpty) return '()';

  // Build individual parameter HTML strings (without group brackets).
  final requiredPositional = <String>[];
  final optionalPositional = <String>[];
  final named = <String>[];

  for (final param in parameters) {
    final buf = StringBuffer();

    if (param.isRequiredNamed) {
      buf.write('<span class="kw">required</span> ');
    }

    buf.write(_renderTypeLinked(param.modelType, paths));
    if (param.name.isNotEmpty) {
      buf.write(' <span class="param">${_htmlEsc(param.name)}</span>');
    }

    final defaultValue = param.defaultValue;
    if (defaultValue != null && defaultValue.isNotEmpty) {
      buf.write(' = ${_wrapDefaultValue(defaultValue)}');
    }

    if (param.isNamed) {
      named.add(buf.toString());
    } else if (param.isOptionalPositional) {
      optionalPositional.add(buf.toString());
    } else {
      requiredPositional.add(buf.toString());
    }
  }

  // Assemble single-line version with correct brackets.
  final singleLine = _buildSingleLineParams(
    requiredPositional,
    optionalPositional,
    named,
  );

  // Check if it fits in 80 columns.
  if (prefixLength + _stripHtmlForLength(singleLine) <= 80) {
    return singleLine;
  }

  // Tall style: one parameter per line, 2-space indent, trailing commas.
  return _buildTallParameterSignature(
    requiredPositional,
    optionalPositional,
    named,
  );
}

/// Assembles a single-line `(...)` parameter list with correct brackets.
String _buildSingleLineParams(
  List<String> requiredPositional,
  List<String> optionalPositional,
  List<String> named,
) {
  final all = <String>[];
  all.addAll(requiredPositional);

  if (optionalPositional.isNotEmpty) {
    all.add('[${optionalPositional.join(', ')}]');
  } else if (named.isNotEmpty) {
    all.add('{${named.join(', ')}}');
  }

  return '(${all.join(', ')})';
}

/// Builds a tall-style (multi-line) parameter signature following dart format.
///
/// Each parameter is on its own line with 2-space indent and a trailing comma.
/// Group brackets (`{`, `}`, `[`, `]`) follow dart format conventions:
/// - Only named: `({\n  p1,\n  p2,\n})`
/// - Only optional: `([\n  p1,\n  p2,\n])`
/// - Only required: `(\n  p1,\n  p2,\n)`
/// - Mixed: `(\n  pos, {\n  named,\n})` — `{`/`[` on same line as last positional
String _buildTallParameterSignature(
  List<String> requiredPositional,
  List<String> optionalPositional,
  List<String> named,
) {
  final buf = StringBuffer();

  if (named.isNotEmpty && requiredPositional.isEmpty) {
    // Only named: ({  p1,  p2,  })
    buf.write('({\n');
    for (final p in named) {
      buf.write('  $p,\n');
    }
    buf.write('})');
    return buf.toString();
  }

  if (optionalPositional.isNotEmpty && requiredPositional.isEmpty) {
    // Only optional positional: ([  p1,  p2,  ])
    buf.write('([\n');
    for (final p in optionalPositional) {
      buf.write('  $p,\n');
    }
    buf.write('])');
    return buf.toString();
  }

  // Has required positional params.
  buf.write('(\n');

  if (named.isNotEmpty) {
    // Mixed: required positional + named.
    // All required except last, then last + { on same line.
    for (var i = 0; i < requiredPositional.length - 1; i++) {
      buf.write('  ${requiredPositional[i]},\n');
    }
    buf.write('  ${requiredPositional.last}, {\n');
    for (final p in named) {
      buf.write('  $p,\n');
    }
    buf.write('})');
  } else if (optionalPositional.isNotEmpty) {
    // Mixed: required positional + optional positional.
    for (var i = 0; i < requiredPositional.length - 1; i++) {
      buf.write('  ${requiredPositional[i]},\n');
    }
    buf.write('  ${requiredPositional.last}, [\n');
    for (final p in optionalPositional) {
      buf.write('  $p,\n');
    }
    buf.write('])');
  } else {
    // Only required positional.
    for (final p in requiredPositional) {
      buf.write('  $p,\n');
    }
    buf.write(')');
  }

  return buf.toString();
}

/// Builds a linked method/function signature as HTML.
String _buildLinkedCallableSignature(
  ModelElement element,
  MarkdownPathResolver paths,
) {
  final fallbackSignature = _buildLinkedCallableSignatureFallback(
    element,
    paths,
  );
  final placeholders = _SignaturePlaceholders();
  final declaration = StringBuffer();

  if (element is Method) {
    declaration.write(
      '${_renderTypePlaceholder(element.modelType.returnType, paths, placeholders)} ',
    );
  } else if (element is ModelFunctionTyped) {
    declaration.write(
      '${_renderTypePlaceholder(element.modelType.returnType, paths, placeholders)} ',
    );
  }

  declaration.write(
    placeholders.token(
      _signaturePlaceholderPrefixFn,
      '<span class="fn">${_htmlEsc(plainNameWithGenerics(element))}</span>',
      plainText: plainNameWithGenerics(element),
    ),
  );
  declaration.write(
    _buildPlaceholderParameterSignature(
      element.parameters,
      paths,
      placeholders,
    ),
  );

  final formatted = _formatLinkedMemberDeclaration(
    declaration.toString(),
    placeholders,
    wrapperClassName: '_SignatureHost',
  );
  if (!_shouldKeepFormattedSignature(formatted, fallbackSignature)) {
    return fallbackSignature;
  }
  return formatted;
}

/// Builds a linked constructor signature as HTML.
String _buildLinkedConstructorSignature(
  Constructor constructor,
  MarkdownPathResolver paths,
) {
  final fallbackSignature = _buildLinkedConstructorSignatureFallback(
    constructor,
    paths,
  );
  final placeholders = _SignaturePlaceholders();
  final declaration = StringBuffer();

  if (constructor.isConst) declaration.write('const ');
  if (constructor.isFactory) declaration.write('factory ');

  declaration.write(
    placeholders.token(
      _signaturePlaceholderPrefixFn,
      '<span class="fn">${_htmlEsc(constructor.displayName)}</span>',
      plainText: constructor.displayName,
    ),
  );
  declaration.write(
    _buildPlaceholderParameterSignature(
      constructor.parameters,
      paths,
      placeholders,
    ),
  );

  final formatted = _formatLinkedMemberDeclaration(
    declaration.toString(),
    placeholders,
    wrapperClassName: constructor.enclosingElement.name,
  );
  if (!_shouldKeepFormattedSignature(formatted, fallbackSignature)) {
    return fallbackSignature;
  }
  return formatted;
}

bool _shouldKeepFormattedSignature(String formatted, String fallback) {
  if (formatted.contains('\n')) return true;
  if (fallback.contains('\n')) return false;
  return _stripHtmlForLength(formatted) <= _stripHtmlForLength(fallback);
}

String _buildLinkedCallableSignatureFallback(
  ModelElement element,
  MarkdownPathResolver paths,
) {
  final buffer = StringBuffer();
  var prefixLength = 0;

  if (element is Method) {
    final returnType = _renderTypeLinked(element.modelType.returnType, paths);
    buffer.write('$returnType ');
    prefixLength += _stripHtmlForLength(returnType) + 1;
  } else if (element is ModelFunctionTyped) {
    final returnType = _renderTypeLinked(element.modelType.returnType, paths);
    buffer.write('$returnType ');
    prefixLength += _stripHtmlForLength(returnType) + 1;
  }

  final fnName = plainNameWithGenerics(element);
  buffer.write('<span class="fn">${_htmlEsc(fnName)}</span>');
  prefixLength += fnName.length;
  buffer.write(
    _buildLinkedParameterSignature(
      element.parameters,
      paths,
      prefixLength: prefixLength,
    ),
  );
  return buffer.toString();
}

String _buildLinkedConstructorSignatureFallback(
  Constructor constructor,
  MarkdownPathResolver paths,
) {
  final buffer = StringBuffer();
  var prefixLength = 0;

  if (constructor.isConst) {
    buffer.write('<span class="kw">const</span> ');
    prefixLength += 'const '.length;
  }
  if (constructor.isFactory) {
    buffer.write('<span class="kw">factory</span> ');
    prefixLength += 'factory '.length;
  }

  final displayName = constructor.displayName;
  buffer.write('<span class="fn">${_htmlEsc(displayName)}</span>');
  prefixLength += displayName.length;
  buffer.write(
    _buildLinkedParameterSignature(
      constructor.parameters,
      paths,
      prefixLength: prefixLength,
    ),
  );
  return buffer.toString();
}

const _signaturePlaceholderPrefixType = '_t';
const _signaturePlaceholderPrefixParam = '_p';
const _signaturePlaceholderPrefixFn = '_f';
