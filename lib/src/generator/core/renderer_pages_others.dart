part of 'api_markdown_renderer.dart';

String renderMixinPage(
  Mixin mixin_,
  Library library,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(mixin_);
  final nameWithGenerics = plainNameWithGenerics(mixin_);

  builder.writeFrontmatter(
    title: nameWithGenerics,
    description:
        'API documentation for $nameWithGenerics mixin from ${library.name}',
    outline: [2, 3],
    outlineCollapsible: _isOutlineCollapsible(mixin_),
    category: 'Mixins',
    library: library.name,
    sourceUrl: mixin_.hasSourceHref ? mixin_.sourceHref : null,
  );

  builder.writeH1(
    nameWithGenerics,
    deprecated: mixin_.isDeprecated,
    badges: _buildModifierBadges(mixin_),
  );

  // Declaration line (linked)
  builder.writeSignature(_buildLinkedMixinDeclaration(mixin_, paths));

  // Deprecation notice
  if (mixin_.isDeprecated) {
    builder.writeDeprecationNotice(_extractDeprecationMessage(mixin_));
  }

  // Annotations
  _renderAnnotations(builder, mixin_);

  // Documentation
  final doc = docs.processDocumentation(mixin_);
  builder.writeParagraph(doc);

  // Inheritance chain
  _renderInheritanceChain(builder, mixin_, paths);

  // Implemented types
  _renderImplementedTypes(builder, mixin_, paths);

  // Mixed-in types
  _renderMixedInTypes(builder, mixin_, paths);

  // Implementers
  _renderImplementors(builder, mixin_, paths);

  // Available Extensions
  _renderAvailableExtensions(builder, mixin_, paths);

  // Superclass constraints
  final constraints = mixin_.publicSuperclassConstraints.toList();
  if (constraints.isNotEmpty) {
    builder.writeInfoContainer(
      'Superclass Constraints',
      constraints.map((c) => escapeGenerics(c.nameWithGenericsPlain)).toList(),
    );
  }

  // Standard container members
  _renderContainerMembers(builder, mixin_, docs, paths);

  return builder.toString();
}

/// Renders an extension page with extended type and all members embedded.
String renderExtensionPage(
  Extension ext,
  Library library,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(ext);
  final nameWithGenerics = plainNameWithGenerics(ext);

  builder.writeFrontmatter(
    title: nameWithGenerics,
    description:
        'API documentation for $nameWithGenerics extension from ${library.name}',
    outline: [2, 3],
    outlineCollapsible: _isOutlineCollapsible(ext),
    category: 'Extensions',
    library: library.name,
    sourceUrl: ext.hasSourceHref ? ext.sourceHref : null,
  );

  builder.writeH1(nameWithGenerics, deprecated: ext.isDeprecated);

  // Declaration line (linked)
  builder.writeSignature(_buildLinkedExtensionDeclaration(ext, paths));

  // Deprecation notice
  if (ext.isDeprecated) {
    builder.writeDeprecationNotice(_extractDeprecationMessage(ext));
  }

  // Annotations
  _renderAnnotations(builder, ext);

  // Documentation
  final doc = docs.processDocumentation(ext);
  builder.writeParagraph(doc);

  // All members
  _renderContainerMembers(builder, ext, docs, paths);

  return builder.toString();
}

/// Renders an extension type page with representation type and all members
/// embedded.
String renderExtensionTypePage(
  ExtensionType et,
  Library library,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(et);
  final nameWithGenerics = plainNameWithGenerics(et);

  builder.writeFrontmatter(
    title: nameWithGenerics,
    description:
        'API documentation for $nameWithGenerics extension type '
        'from ${library.name}',
    outline: [2, 3],
    outlineCollapsible: _isOutlineCollapsible(et),
    category: 'Extension Types',
    library: library.name,
    sourceUrl: et.hasSourceHref ? et.sourceHref : null,
  );

  builder.writeH1(
    nameWithGenerics,
    deprecated: et.isDeprecated,
    badges: _buildModifierBadges(et),
  );

  // Declaration line (linked)
  builder.writeSignature(_buildLinkedExtensionTypeDeclaration(et, paths));

  // Deprecation notice
  if (et.isDeprecated) {
    builder.writeDeprecationNotice(_extractDeprecationMessage(et));
  }

  // Annotations
  _renderAnnotations(builder, et);

  // Documentation
  final doc = docs.processDocumentation(et);
  builder.writeParagraph(doc);

  // Implementers
  _renderImplementors(builder, et, paths);

  // All members (including constructors via Constructable)
  _renderContainerMembers(builder, et, docs, paths);

  return builder.toString();
}

/// Renders a top-level function page.
String renderFunctionPage(
  ModelFunction func,
  Library library,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(func);
  final nameWithGenerics = plainNameWithGenerics(func);

  builder.writeFrontmatter(
    title: '$nameWithGenerics function',
    description:
        'API documentation for the $nameWithGenerics function '
        'from ${library.name}',
    outline: false,
    category: 'Functions',
    library: library.name,
    sourceUrl: func.hasSourceHref ? func.sourceHref : null,
  );

  builder.writeH1(nameWithGenerics, deprecated: func.isDeprecated);

  // Signature
  builder.writeSignature(_buildLinkedCallableSignature(func, paths));

  // Deprecation notice
  if (func.isDeprecated) {
    builder.writeDeprecationNotice(_extractDeprecationMessage(func));
  }

  // Annotations
  _renderAnnotations(builder, func);

  // Documentation
  final doc = docs.processDocumentation(func);
  builder.writeParagraph(doc);

  return builder.toString();
}

/// Renders a top-level property or constant page.
String renderPropertyPage(
  TopLevelVariable prop,
  Library library,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(prop);

  final kindLabel = prop.isConst ? 'constant' : 'property';

  final sidebarKind = prop.isConst ? 'Constants' : 'Properties';

  builder.writeFrontmatter(
    title: '${prop.name} $kindLabel',
    description:
        'API documentation for the ${prop.name} $kindLabel '
        'from ${library.name}',
    outline: false,
    category: sidebarKind,
    library: library.name,
    sourceUrl: prop.hasSourceHref ? prop.sourceHref : null,
  );

  builder.writeH1(prop.name, deprecated: prop.isDeprecated);

  // Signature
  builder.writeSignature(_buildLinkedPropertySignature(prop, paths));

  // Deprecation notice
  if (prop.isDeprecated) {
    builder.writeDeprecationNotice(_extractDeprecationMessage(prop));
  }

  // Annotations
  _renderAnnotations(builder, prop);

  // Documentation
  final doc = docs.processDocumentation(prop);
  builder.writeParagraph(doc);

  return builder.toString();
}

/// Renders a typedef page.
String renderTypedefPage(
  Typedef td,
  Library library,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(td);
  final nameWithGenerics = plainNameWithGenerics(td);

  builder.writeFrontmatter(
    title: '$nameWithGenerics typedef',
    description:
        'API documentation for the $nameWithGenerics typedef '
        'from ${library.name}',
    outline: false,
    category: 'Typedefs',
    library: library.name,
  );

  builder.writeH1(nameWithGenerics, deprecated: td.isDeprecated);

  // Typedef declaration
  final sig = StringBuffer(
    '<span class="kw">typedef</span> <span class="fn">${_htmlEsc(nameWithGenerics)}</span> = ',
  );

  if (td is FunctionTypedef) {
    // Function typedef: show the return type and parameter types
    sig.write(_renderTypeLinked(td.modelType.returnType, paths));
    sig.write(' <span class="type">Function</span>');
    final prefixLength = _stripHtmlForLength(sig.toString());
    sig.write(
      _buildLinkedParameterSignature(
        td.parameters,
        paths,
        prefixLength: prefixLength,
      ),
    );
  } else {
    // Type alias (ClassTypedef, GeneralizedTypedef)
    sig.write(_renderTypeLinked(td.modelType, paths));
  }

  builder.writeSignature(sig.toString());

  // Deprecation notice
  if (td.isDeprecated) {
    builder.writeDeprecationNotice(_extractDeprecationMessage(td));
  }

  // Documentation
  final doc = docs.processDocumentation(td);
  builder.writeParagraph(doc);

  return builder.toString();
}

/// Renders a category/topic page.
String renderCategoryPage(
  Category cat,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(cat);

  builder.writeFrontmatter(
    title: cat.name,
    description: 'API documentation for the ${cat.name} topic',
    outline: [2, 3],
  );

  builder.writeH1(cat.name);

  // Category documentation (processed through doc processor for directives)
  final catDoc = docs.processRawDocumentation(cat.documentation);
  if (catDoc.isNotEmpty) {
    builder.writeParagraph(catDoc);
  }

  // Element groups (same order as library pages)
  _renderLibraryOverviewTable(
    builder,
    'Classes',
    cat.publicClassesSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Exceptions',
    cat.publicExceptionsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Enums',
    cat.publicEnumsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Mixins',
    cat.publicMixinsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderExtensionsTable(builder, cat.publicExtensionsSorted, paths, docs);

  _renderLibraryOverviewTable(
    builder,
    'Extension Types',
    cat.publicExtensionTypesSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Functions',
    cat.publicFunctionsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Properties',
    cat.publicPropertiesSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Constants',
    cat.publicConstantsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Typedefs',
    cat.publicTypedefsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  return builder.toString();
}

// ---------------------------------------------------------------------------
// Private helpers.
// ---------------------------------------------------------------------------

/// Renders an extensions table with the special "on Type" column.
void _renderExtensionsTable(
  _MarkdownPageBuilder builder,
  List<Extension> extensions,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  if (extensions.isEmpty) return;

  builder.writeH2('Extensions');
  final rows = <List<String>>[];
  for (final ext in extensions) {
    final link = _markdownLink(ext, paths);
    final onType = ext.extendedElement.nameWithGenericsPlain;
    final oneLineDoc = docs.extractOneLineDoc(ext);
    final isDeprecated = ext.isDeprecated;
    final nameCell = isDeprecated ? '~~$link~~' : link;
    final descCell = isDeprecated && oneLineDoc.isNotEmpty
        ? '**Deprecated.** $oneLineDoc'
        : oneLineDoc;
    rows.add([nameCell, escapeGenerics(onType), descCell]);
  }
  builder.writeTable(headers: ['Extension', 'on', 'Description'], rows: rows);
}

// Plain-text mixin/extension-type declarations (kept for potential future use).
//
// String _buildMixinDeclaration(Mixin mixin_) { ... }
// String _buildExtensionTypeDeclaration(ExtensionType et) { ... }

/// Returns `true` if the library has any public API elements (classes,
/// functions, enums, etc.).
///
/// Stub libraries (e.g. `dart.core` forwarding to `dart:core`) pass the
/// `isPublic && isDocumented` filters but contain zero actual elements.
/// This helper detects them so they can be excluded from index pages.
bool _hasApiElements(Library library) {
  return library.publicClassesSorted.isNotEmpty ||
      library.publicExceptionsSorted.isNotEmpty ||
      library.publicEnumsSorted.isNotEmpty ||
      library.publicMixinsSorted.isNotEmpty ||
      library.publicExtensionsSorted.isNotEmpty ||
      library.publicExtensionTypesSorted.isNotEmpty ||
      library.publicFunctionsSorted.isNotEmpty ||
      library.publicPropertiesSorted.isNotEmpty ||
      library.publicConstantsSorted.isNotEmpty ||
      library.publicTypedefsSorted.isNotEmpty;
}

/// Strips or downgrades a leading `# title` from documentation text.
///
/// If the H1 matches [expectedTitle], it is stripped entirely to avoid
/// duplication (README files often start with `# PackageName`).
/// If the H1 does NOT match, it is downgraded to H2 (`##`) to prevent
/// multiple H1 headings on the page (only the generator's own H1 should
/// remain as the page title).
String _stripLeadingH1(String text, String expectedTitle) {
  final match = _leadingH1RegExp.firstMatch(text);
  if (match == null) return text;

  final title = match.group(1)!.trim();
  // Normalize hyphens/underscores for comparison, since VitePress treats
  // them identically when generating heading slugs. A README titled
  // "dartdoc_modern" should match package name "dartdoc_modern".
  final normalizedTitle = title.toLowerCase().replaceAll('-', '_');
  final normalizedExpected = expectedTitle.toLowerCase().replaceAll('-', '_');
  if (normalizedTitle == normalizedExpected) {
    // Duplicate (modulo hyphen/underscore/case) -- strip entirely.
    var result = text.substring(match.end).trimLeft();
    // Also strip leading badge lines (e.g. shields.io) that commonly
    // follow the package H1 in READMEs. These are redundant on API pages.
    result = result.replaceAll(
      RegExp(
        r'^\[!\[[^\]]*\]\(https://img\.shields\.io/[^)]*\)\]\([^)]*\)\s*',
        multiLine: true,
      ),
      '',
    );
    return result.trimLeft();
  }
  // Different H1 from user content -- downshift to H2.
  return '## ${match.group(1)}${match.group(2) ?? ''}${text.substring(match.end)}';
}
