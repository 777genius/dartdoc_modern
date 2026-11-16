part of 'api_markdown_renderer.dart';

String _postProcessMemberDoc(String doc, {required String memberAnchor}) {
  final lines = doc.split('\n');
  final result = <String>[];
  for (final line in lines) {
    var processed = line;
    // Match markdown headings: ^#{1,6} ...
    final headingMatch = RegExp(r'^(#{1,6})\s').firstMatch(processed);
    if (headingMatch != null) {
      // Strip explicit {#...} ID suffixes
      processed = processed.replaceAll(RegExp(r'\s*\{#[^}]+\}\s*$'), '');
      // Increase heading depth by 2 (members are under H3)
      final hashes = headingMatch.group(1)!;
      final newDepth = hashes.length + 2;
      if (newDepth <= 6) {
        processed = processed.replaceFirst(hashes, '#' * newDepth);
      }
      // Extract the heading text (after the hashes and space) for slug generation
      final headingText = processed.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
      final headingSlug = MarkdownPathResolver.sanitizeAnchor(headingText);
      if (headingSlug.isNotEmpty) {
        processed = '$processed {#$memberAnchor-$headingSlug}';
      }
    }
    result.add(processed);
  }
  return result.join('\n');
}

void _renderMemberDocumentation(
  _MarkdownPageBuilder builder,
  ModelElement element,
  MarkdownDocProcessor docs,
  MarkdownPathResolver paths, {
  required String memberAnchor,
}) {
  // Deprecation warning
  if (element.isDeprecated) {
    builder.writeDeprecationNotice(_extractDeprecationMessage(element));
  }

  // Main documentation — separate getter/setter docs when both have documentation
  if (element is Field && element.getterSetterBothAvailable) {
    final getterDoc = docs.processDocumentation(element.getter!);
    final setterDoc = docs.processDocumentation(element.setter!);
    final combinedDoc = StringBuffer();
    if (getterDoc.isNotEmpty) {
      combinedDoc.writeln('**getter:**\n');
      combinedDoc.writeln(getterDoc);
      combinedDoc.writeln();
    }
    if (setterDoc.isNotEmpty) {
      combinedDoc.writeln('**setter:**\n');
      combinedDoc.writeln(setterDoc);
    }
    var doc = combinedDoc.toString().trimRight();
    doc = _postProcessMemberDoc(doc, memberAnchor: memberAnchor);
    builder.writeParagraph(doc);
  } else {
    var doc = docs.processDocumentation(element);
    doc = _postProcessMemberDoc(doc, memberAnchor: memberAnchor);
    builder.writeParagraph(doc);
  }

  // Inherited-from notice: use the analyzer element's enclosing element name
  // to find the defining class. This avoids accessing `definingEnclosingContainer`
  // which is @protected/@visibleForTesting.
  if (element is Inheritable && element.isInherited) {
    final definingClassName =
        element.element.enclosingElement?.name ?? 'unknown';
    builder.writeInheritedFrom(definingClassName);
  }

  // Extension attribution notice — matches api.dart.dev format:
  // "Available on Type, provided by the ExtensionName extension"
  if ((element is Method && element.isProvidedByExtension) ||
      (element is Field && element.isProvidedByExtension)) {
    final ext = element is Method
        ? element.enclosingExtension
        : (element as Field).enclosingExtension;
    final extLink = _markdownLink(ext, paths);
    final onType = ext.extendedElement;
    final onTypeName = onType is DefinedElementType
        ? _markdownLink(onType.modelElement, paths)
        : escapeGenerics(onType.nameWithGenericsPlain);
    builder.writeParagraph(
      '*Available on $onTypeName, provided by the $extLink extension*',
    );
  }
}

/// Computes the anchor ID for a member element.
///
/// For operators, maps the symbol to a URL-safe name.
/// For constructors, uses the constructor name lowercased.
/// For other members, uses the element name lowercased.
String _memberAnchor(ModelElement element) {
  if (element is Operator) {
    // The reference name is the raw operator symbol (e.g., '==', '[]')
    final refName = element.referenceName;
    final anchorSuffix = operatorNames[refName] ?? refName.toLowerCase();
    return 'operator-$anchorSuffix';
  }
  if (element is Constructor) {
    if (element.isUnnamedConstructor) {
      // Prefix with 'ctor-' to avoid collision with VitePress auto-generated
      // ID for the class H1 heading (which would also be lowercased class name).
      return 'ctor-${element.enclosingElement.name.toLowerCase()}';
    }
    return element.element.name!.toLowerCase();
  }
  final name = element.name.toLowerCase();
  // Prefix property anchors to avoid collision with methods of the same name
  // (e.g. property `s` and method `s()` would both produce anchor `{#s}`).
  if (element is Field) {
    return 'prop-$name';
  }
  return name;
}

/// Renders annotations for an element (excluding `@Deprecated` which is
/// handled separately as a deprecation notice).
///
/// Uses the source representation of each annotation for plain-text output
/// (the `linkedNameWithParameters` getter produces HTML, which is not
/// suitable for markdown).
void _renderAnnotations(_MarkdownPageBuilder builder, ModelElement element) {
  if (!element.hasAnnotations) return;
  final annotations = element.annotations
      .map(_annotationPlainText)
      .where(
        (text) => text != '@deprecated' && !text.startsWith('@Deprecated('),
      )
      .map((text) => '`$text`')
      .toList();
  if (annotations.isEmpty) return;
  builder.writeParagraph('**Annotations:** ${annotations.join(', ')}');
}

/// Converts an annotation's `linkedNameWithParameters` (which may contain
/// HTML tags and entities) into plain text suitable for markdown output.
String _annotationPlainText(Attribute annotation) {
  return annotation.linkedNameWithParameters
      .replaceAll(_htmlTagRegExp, '') // Strip HTML tags
      .replaceAll('&lt;', '<')
      .replaceAll('&#60;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#62;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&#38;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&#39;', "'");
}

/// Renders the inheritance chain for a container (class/enum/mixin).
///
/// Shows: `Object → Ancestor → ... → CurrentClass` using `publicSuperChainReversed`.
/// Object is plain text, intermediate types are markdown links, current class is bold.
void _renderInheritanceChain(
  _MarkdownPageBuilder builder,
  InheritingContainer container,
  MarkdownPathResolver paths,
) {
  final chain = container.publicSuperChainReversed.toList();
  if (chain.isEmpty) return;

  final parts = <String>['Object'];
  for (final type in chain) {
    parts.add(_markdownLink(type.modelElement, paths));
  }
  // Current class — bold, no link
  parts.add('**${escapeGenerics(plainNameWithGenerics(container))}**');

  builder.writeParagraph(':::info Inheritance\n${parts.join(' → ')}\n:::');
}

/// Renders the "Implemented types" info block for a container.
void _renderImplementedTypes(
  _MarkdownPageBuilder builder,
  InheritingContainer container,
  MarkdownPathResolver paths,
) {
  final interfaces = container.publicInterfaces;
  if (interfaces.isEmpty) return;

  builder.writeInfoContainer(
    'Implemented types',
    interfaces.map((i) => _markdownLink(i.modelElement, paths)).toList(),
  );
}

/// Renders the "Mixed-in types" info block for a container.
void _renderMixedInTypes(
  _MarkdownPageBuilder builder,
  InheritingContainer container,
  MarkdownPathResolver paths,
) {
  if (container is! MixedInTypes) return;
  final mixins = container.publicMixedInTypes.toList();
  if (mixins.isEmpty) return;

  builder.writeInfoContainer(
    'Mixed-in types',
    mixins.map((m) => _markdownLink(m.modelElement, paths)).toList(),
  );
}

/// Renders the "Implementers" section for a class/interface.
void _renderImplementors(
  _MarkdownPageBuilder builder,
  InheritingContainer container,
  MarkdownPathResolver paths,
) {
  final implementors = container.publicImplementersSorted;
  if (implementors.isEmpty) return;

  builder.writeInfoContainer(
    'Implementers',
    implementors.map((impl) => _markdownLink(impl, paths)).toList(),
  );
}

/// Renders the "Available Extensions" section for a class.
void _renderAvailableExtensions(
  _MarkdownPageBuilder builder,
  InheritingContainer container,
  MarkdownPathResolver paths,
) {
  final extensions = container.potentiallyApplicableExtensionsSorted;
  if (extensions.isEmpty) return;

  builder.writeInfoContainer(
    'Available Extensions',
    extensions.map((ext) => _markdownLink(ext, paths)).toList(),
  );
}

/// Renders a library overview table for a specific element kind group.
void _renderLibraryOverviewTable(
  _MarkdownPageBuilder builder,
  String sectionTitle,
  List<Documentable> elements,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  if (elements.isEmpty) return;

  // Filter out elements that don't have a link (e.g. re-exported external/SDK
  // classes whose canonical library is not local). The sidebar already excludes
  // these via _belongsToLibrary() filtering; apply the same logic here.
  final linkableElements = elements
      .where((e) => paths.linkFor(e) != null)
      .toList();
  if (linkableElements.isEmpty) return;

  builder.writeH2(sectionTitle);

  final rows = <List<String>>[];
  for (final element in linkableElements) {
    final link = _markdownLink(element, paths);
    final oneLineDoc = element is ModelElement
        ? docs.extractOneLineDoc(element)
        : (element.documentation ?? '');

    final isDeprecated = element is ModelElement && element.isDeprecated;
    final nameCell = isDeprecated ? '~~$link~~' : link;

    final descCell = isDeprecated && oneLineDoc.isNotEmpty
        ? '**Deprecated.** $oneLineDoc'
        : oneLineDoc;

    rows.add([nameCell, descCell]);
  }

  const singularNames = {
    'Classes': 'Class',
    'Exceptions': 'Exception',
    'Enums': 'Enum',
    'Mixins': 'Mixin',
    'Extensions': 'Extension',
    'Extension Types': 'Extension Type',
    'Functions': 'Function',
    'Properties': 'Property',
    'Constants': 'Constant',
    'Typedefs': 'Typedef',
  };
  final singularName = singularNames[sectionTitle] ?? sectionTitle;

  builder.writeTable(headers: [singularName, 'Description'], rows: rows);
}
