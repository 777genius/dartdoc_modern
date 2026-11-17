part of 'api_markdown_renderer.dart';

// ---------------------------------------------------------------------------
// Pre-compiled regular expressions (avoid re-creating on every call).
// ---------------------------------------------------------------------------

/// Matches HTML tags for stripping in [_annotationPlainText].
final _htmlTagRegExp = RegExp(r'<[^>]*>');

/// Matches a leading `# Title` line in documentation text.
final _leadingH1RegExp = RegExp(r'^#\s+(.+?)(\r?\n|$)');

/// Returns the plain-text length of [html] after stripping tags and decoding
/// common HTML entities. Used for measuring signature length against the
/// 80-column threshold.
int _stripHtmlForLength(String html) {
  return html
      .replaceAll(_htmlTagRegExp, '')
      .replaceAll('&lt;', '<')
      .replaceAll('&#60;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#62;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&#38;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&#39;', "'")
      .length;
}

// ---------------------------------------------------------------------------
// Shared rendering helpers.
// ---------------------------------------------------------------------------

/// Builds VitePress Badge strings for a container's modifiers.
///
/// Skips modifiers that are already in the declaration (e.g., "class", "enum")
/// and filters using the `hideIfPresent` rules. Returns a list of Badge HTML
/// strings like `<Badge type="info" text="sealed" />`.
List<String> _buildModifierBadges(InheritingContainer container) {
  final badges = <String>[];
  final modifiers = container.containerModifiers;

  for (final modifier in modifiers) {
    // Skip modifiers that should be hidden when another modifier is present
    if (modifier.hideIfPresent.any(modifiers.contains)) continue;

    badges.add('<Badge type="info" text="${modifier.displayName}" />');
  }

  return badges;
}

/// Maps built-in [Attribute] constants to VitePress Badge (type, text) pairs.
///
/// Only "feature" attributes (no setter, inherited, override, etc.) are shown;
/// annotation attributes (like `@protected`) are rendered by [_renderAnnotations].
final _memberBadgeMap = <Attribute, (String type, String text)>{
  Attribute.noSetter: ('tip', 'no setter'),
  Attribute.noGetter: ('tip', 'no getter'),
  Attribute.getterSetterPair: ('tip', 'read / write'),
  Attribute.inherited: ('info', 'inherited'),
  Attribute.inheritedGetter: ('info', 'inherited-getter'),
  Attribute.inheritedSetter: ('info', 'inherited-setter'),
  Attribute.override_: ('info', 'override'),
  Attribute.overrideGetter: ('info', 'override-getter'),
  Attribute.overrideSetter: ('info', 'override-setter'),
  Attribute.extended: ('info', 'extended'),
  Attribute.late_: ('warning', 'late'),
  Attribute.final_: ('tip', 'final'),
  Attribute.covariant: ('info', 'covariant'),
};

/// Builds VitePress Badge strings for a member element's attributes.
///
/// Returns badges for properties (no setter, inherited, etc.), methods
/// (inherited, override), and constructors (factory, const).
List<String> _buildMemberBadges(ModelElement element) {
  final badges = <String>[];

  // Constructor-specific badges.
  if (element is Constructor) {
    if (element.isFactory) {
      badges.add('<Badge type="tip" text="factory" />');
    }
    if (element.isConst) {
      badges.add('<Badge type="tip" text="const" />');
    }
  }

  // Method-specific badges.
  if (element is Method) {
    if (element.isInherited) {
      badges.add('<Badge type="info" text="inherited" />');
    }
    if (element.attributes.contains(Attribute.override_)) {
      badges.add('<Badge type="info" text="override" />');
    }
    if (element.isProvidedByExtension) {
      badges.add('<Badge type="info" text="extension" />');
    }
  }

  // Field/property badges from attributes.
  if (element is Field) {
    if (element.isProvidedByExtension) {
      badges.add('<Badge type="info" text="extension" />');
    }
    // Sort attributes by sortGroup for consistent ordering.
    final sortedAttrs = element.attributes.toList()
      ..sort((a, b) => a.sortGroup.compareTo(b.sortGroup));
    for (final attr in sortedAttrs) {
      final badge = _memberBadgeMap[attr];
      if (badge != null) {
        badges.add('<Badge type="${badge.$1}" text="${badge.$2}" />');
      }
    }
  }

  return badges;
}

/// Builds a markdown link for a documentable element.
///
/// Returns `[DisplayName](/api/lib/ClassName)` if a URL is available,
/// or just the display name as plain text if not.
String _markdownLink(Documentable element, MarkdownPathResolver paths) {
  final url = paths.linkFor(element);
  // Use full name with generics for elements that have type parameters.
  final rawName = element is ModelElement
      ? plainNameWithGenerics(element)
      : element.name;
  final name = escapeGenerics(rawName);
  if (url == null) return name;
  return '[$name]($url)';
}

/// Extracts the deprecation message from an element's annotations.
///
/// Uses the analyzer's `ElementAnnotation` to find the `@Deprecated` annotation
/// and retrieve its `message` field via `computeConstantValue()`.
String _extractDeprecationMessage(ModelElement element) {
  for (final annotation in element.element.metadata.annotations) {
    if (!annotation.isDeprecated) continue;
    final value = annotation.computeConstantValue();
    if (value == null) continue;
    final message = value.getField('message')?.toStringValue();
    if (message != null && message.isNotEmpty) return message;
  }
  return '';
}

// Plain-text container declaration (kept for potential future use, e.g. RSS,
// search index). Linked version below is used for rendering.
//
// String _buildContainerDeclaration(InheritingContainer container) { ... }

/// Builds linked HTML container declaration (class/enum) with clickable types.
String _buildLinkedContainerDeclaration(
  InheritingContainer container,
  MarkdownPathResolver paths,
) {
  final buf = StringBuffer();

  // Modifiers as keyword spans
  for (final modifier in container.containerModifiers) {
    if (modifier == ContainerModifier.abstract &&
        container.containerModifiers.contains(ContainerModifier.sealed)) {
      continue;
    }
    buf.write('<span class="kw">${_htmlEsc(modifier.displayName)}</span> ');
  }

  // Kind keyword
  if (container is Class) {
    buf.write('<span class="kw">class</span> ');
  } else if (container is Enum) {
    buf.write('<span class="kw">enum</span> ');
  }

  // Name
  buf.write('<span class="fn">${_htmlEsc(container.name)}</span>');
  // Type parameters
  if (container.typeParameters.isNotEmpty) {
    buf.write('&lt;');
    buf.write(
      container.typeParameters
          .map((tp) {
            final tpBuf = StringBuffer(_htmlEsc(tp.element.name!));
            if (tp.boundType != null) {
              tpBuf.write(' <span class="kw">extends</span> ');
              tpBuf.write(_renderTypeLinked(tp.boundType!, paths));
            }
            return tpBuf.toString();
          })
          .join(', '),
    );
    buf.write('&gt;');
  }

  // Extends clause
  final supertype = container.supertype;
  if (supertype != null &&
      supertype.modelElement.name != 'Object' &&
      supertype.modelElement.name != 'Enum') {
    buf.write(' <span class="kw">extends</span> ');
    buf.write(_renderTypeLinked(supertype, paths));
  }

  // With clause
  if (container is MixedInTypes) {
    final mixins = container.publicMixedInTypes.toList();
    if (mixins.isNotEmpty) {
      buf.write(' <span class="kw">with</span> ');
      buf.write(mixins.map((m) => _renderTypeLinked(m, paths)).join(', '));
    }
  }

  // Implements clause
  if (container.publicInterfaces.isNotEmpty) {
    buf.write(' <span class="kw">implements</span> ');
    buf.write(
      container.publicInterfaces
          .map((i) => _renderTypeLinked(i, paths))
          .join(', '),
    );
  }

  return buf.toString();
}

/// Builds linked HTML mixin declaration with clickable types.
String _buildLinkedMixinDeclaration(Mixin mixin_, MarkdownPathResolver paths) {
  final buf = StringBuffer();

  // Modifiers
  for (final modifier in mixin_.containerModifiers) {
    buf.write('<span class="kw">${_htmlEsc(modifier.displayName)}</span> ');
  }

  buf.write('<span class="kw">mixin</span> ');
  buf.write('<span class="fn">${_htmlEsc(mixin_.name)}</span>');

  // Type parameters
  if (mixin_.typeParameters.isNotEmpty) {
    buf.write('&lt;');
    buf.write(
      mixin_.typeParameters
          .map((tp) {
            final tpBuf = StringBuffer(_htmlEsc(tp.element.name!));
            if (tp.boundType != null) {
              tpBuf.write(' <span class="kw">extends</span> ');
              tpBuf.write(_renderTypeLinked(tp.boundType!, paths));
            }
            return tpBuf.toString();
          })
          .join(', '),
    );
    buf.write('&gt;');
  }

  // On clause (superclass constraints)
  final constraints = mixin_.publicSuperclassConstraints.toList();
  if (constraints.isNotEmpty) {
    buf.write(' <span class="kw">on</span> ');
    buf.write(constraints.map((c) => _renderTypeLinked(c, paths)).join(', '));
  }

  // Implements clause
  if (mixin_.publicInterfaces.isNotEmpty) {
    buf.write(' <span class="kw">implements</span> ');
    buf.write(
      mixin_.publicInterfaces
          .map((i) => _renderTypeLinked(i, paths))
          .join(', '),
    );
  }

  return buf.toString();
}

/// Builds linked HTML extension declaration with clickable "on" type.
String _buildLinkedExtensionDeclaration(
  Extension ext,
  MarkdownPathResolver paths,
) {
  final buf = StringBuffer();
  buf.write('<span class="kw">extension</span> ');
  buf.write('<span class="fn">${_htmlEsc(ext.name)}</span>');

  // Type parameters
  if (ext.typeParameters.isNotEmpty) {
    buf.write('&lt;');
    buf.write(
      ext.typeParameters
          .map((tp) {
            final tpBuf = StringBuffer(_htmlEsc(tp.element.name!));
            if (tp.boundType != null) {
              tpBuf.write(' <span class="kw">extends</span> ');
              tpBuf.write(_renderTypeLinked(tp.boundType!, paths));
            }
            return tpBuf.toString();
          })
          .join(', '),
    );
    buf.write('&gt;');
  }

  buf.write(' <span class="kw">on</span> ');
  buf.write(_renderTypeLinked(ext.extendedElement, paths));

  return buf.toString();
}

/// Builds linked HTML extension type declaration with clickable types.
String _buildLinkedExtensionTypeDeclaration(
  ExtensionType et,
  MarkdownPathResolver paths,
) {
  final buf = StringBuffer();
  buf.write('<span class="kw">extension type</span> ');
  buf.write('<span class="fn">${_htmlEsc(et.name)}</span>');

  // Type parameters
  if (et.typeParameters.isNotEmpty) {
    buf.write('&lt;');
    buf.write(
      et.typeParameters
          .map((tp) {
            final tpBuf = StringBuffer(_htmlEsc(tp.element.name!));
            if (tp.boundType != null) {
              tpBuf.write(' <span class="kw">extends</span> ');
              tpBuf.write(_renderTypeLinked(tp.boundType!, paths));
            }
            return tpBuf.toString();
          })
          .join(', '),
    );
    buf.write('&gt;');
  }

  // Representation type
  buf.write('(${_renderTypeLinked(et.representationType, paths)})');

  // Implements clause
  if (et.publicInterfaces.isNotEmpty) {
    buf.write(' <span class="kw">implements</span> ');
    buf.write(
      et.publicInterfaces.map((i) => _renderTypeLinked(i, paths)).join(', '),
    );
  }

  return buf.toString();
}

// ---------------------------------------------------------------------------
// Plain-text signature helpers (kept for potential future use, e.g. RSS feeds,
// search index generation, or fallback rendering without HTML).
// ---------------------------------------------------------------------------

// String _renderTypePlain(ElementType type) {
//   if (type is Callable) {
//     final buf = StringBuffer();
//     buf.write(_renderTypePlain(type.returnType));
//     buf.write(' ');
//     buf.write(type.nameWithGenericsPlain);
//     buf.write('(');
//     buf.write(_buildCallableParameterList(type.parameters));
//     buf.write(')');
//     if (type.nullabilitySuffix.isNotEmpty) {
//       return '($buf)${type.nullabilitySuffix}';
//     }
//     return buf.toString();
//   }
//   return type.nameWithGenericsPlain;
// }
//
// String _buildCallableParameterList(List<Parameter> parameters) {
//   if (parameters.isEmpty) return '';
//   final parts = <String>[];
//   var inOptionalPositional = false;
//   var inNamed = false;
//   for (final param in parameters) {
//     final buf = StringBuffer();
//     if (param.isOptionalPositional && !inOptionalPositional) {
//       inOptionalPositional = true;
//       buf.write('[');
//     } else if (param.isNamed && !inNamed) {
//       inNamed = true;
//       buf.write('{');
//     }
//     if (param.isRequiredNamed) buf.write('required ');
//     buf.write(_renderTypePlain(param.modelType));
//     if (param.name.isNotEmpty) buf.write(' ${param.name}');
//     final defaultValue = param.defaultValue;
//     if (defaultValue != null && defaultValue.isNotEmpty) {
//       buf.write(' = $defaultValue');
//     }
//     parts.add(buf.toString());
//   }
//   var result = parts.join(', ');
//   if (inOptionalPositional) result += ']';
//   if (inNamed) result += '}';
//   return result;
// }
//
// String _buildParameterSignature(List<Parameter> parameters) {
//   if (parameters.isEmpty) return '()';
//   final parts = <String>[];
//   var inOptionalPositional = false;
//   var inNamed = false;
//   for (final param in parameters) {
//     final buf = StringBuffer();
//     if (param.isOptionalPositional && !inOptionalPositional) {
//       inOptionalPositional = true;
//       buf.write('[');
//     } else if (param.isNamed && !inNamed) {
//       inNamed = true;
//       buf.write('{');
//     }
//     if (param.isRequiredNamed) buf.write('required ');
//     buf.write(_renderTypePlain(param.modelType));
//     if (param.name.isNotEmpty) buf.write(' ${param.name}');
//     final defaultValue = param.defaultValue;
//     if (defaultValue != null && defaultValue.isNotEmpty) {
//       buf.write(' = $defaultValue');
//     }
//     parts.add(buf.toString());
//   }
//   var result = parts.join(', ');
//   if (inOptionalPositional) result += ']';
//   if (inNamed) result += '}';
//   return '($result)';
// }
//
// String _buildCallableSignature(ModelElement element) {
//   final buf = StringBuffer();
//   if (element is Method) {
//     buf.write('${_renderTypePlain(element.modelType.returnType)} ');
//   } else if (element is ModelFunctionTyped) {
//     buf.write('${_renderTypePlain(element.modelType.returnType)} ');
//   }
//   buf.write(plainNameWithGenerics(element));
//   buf.write(_buildParameterSignature(element.parameters));
//   return buf.toString();
// }
//
// String _buildConstructorSignature(Constructor constructor) {
//   final buf = StringBuffer();
//   if (constructor.isConst) buf.write('const ');
//   if (constructor.isFactory) buf.write('factory ');
//   buf.write(constructor.displayName);
//   buf.write(_buildParameterSignature(constructor.parameters));
//   return buf.toString();
// }
