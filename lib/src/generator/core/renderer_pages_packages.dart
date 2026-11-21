part of 'api_markdown_renderer.dart';

// ---------------------------------------------------------------------------
// Public rendering functions.
// ---------------------------------------------------------------------------

/// Renders the package overview page (`api/index.md`).
///
/// Lists all documented libraries with their descriptions.
String renderPackagePage(
  Package package,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(package);

  builder.writeFrontmatter(
    title: package.name,
    description: 'API documentation for the ${package.name} package',
    outline: false,
  );

  builder.writeH1(package.name);

  // Package documentation (strip leading H1 if it matches the package name
  // to avoid a duplicate heading, since README often starts with # PackageName).
  // Process through processRawDocumentation to convert dartdoc-style .html
  // links to VitePress paths.
  var packageDoc = package.documentation;
  if (packageDoc != null && packageDoc.isNotEmpty) {
    packageDoc = _stripLeadingH1(packageDoc, package.name);
    packageDoc = docs.processRawDocumentation(packageDoc);
    if (packageDoc.isNotEmpty) {
      builder.writeParagraph(packageDoc);
    }
  }

  // Libraries table (filter out stub libraries with no API elements and
  // duplicate internal SDK libraries like `dart.collection`).
  final allLibs = package.libraries.toList();
  final libraries =
      allLibs
          .where((lib) => lib.isPublic && lib.isDocumented)
          .where(_hasApiElements)
          .where((lib) => !isDuplicateSdkLibrary(lib, allLibs))
          .where((lib) => !isInternalSdkLibrary(lib))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  if (libraries.isNotEmpty) {
    builder.writeH2('Libraries');

    final rows = <List<String>>[];
    for (final lib in libraries) {
      final link = _markdownLink(lib, paths);
      var description = docs.extractOneLineDoc(lib);
      // Fall back to the pubspec.yaml description when the library itself
      // has no doc comment (common for single-library packages).
      if (description.isEmpty) {
        description = package.packageMeta.description;
      }
      rows.add([link, description]);
    }

    builder.writeTable(headers: ['Library', 'Description'], rows: rows);
  }

  return builder.toString();
}

/// Renders a workspace overview page (`api/index.md`) when multiple local
/// packages are being documented together.
///
/// Shows each local package as a section with its pubspec description and
/// a table of its public libraries.
String renderWorkspaceOverview(
  PackageGraph packageGraph,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  final workspaceName = packageGraph.defaultPackageName;

  builder.writeFrontmatter(
    title: workspaceName,
    description: 'API documentation for the $workspaceName workspace',
    outline: [2, 3],
  );

  builder.writeH1(workspaceName);
  builder.writeParagraph('This workspace contains the following packages.');

  // Sort packages by name for deterministic output.
  final localPackages = [...packageGraph.localPackages]
    ..sort((a, b) => a.name.compareTo(b.name));

  builder.writeH2('Packages');

  for (final package in localPackages) {
    // Package sub-heading (h3 with anchor).
    final anchor = package.name.toLowerCase().replaceAll(' ', '-');
    builder.writeH3WithAnchor(package.name, anchor: anchor);

    // Package description from pubspec.yaml.
    final description = package.packageMeta.description;
    if (description.isNotEmpty) {
      builder.writeParagraph(description);
    }

    // Libraries table for this package (filter out stub libraries and
    // duplicate internal SDK libraries).
    final allPackageLibs = package.libraries.toList();
    final libraries =
        allPackageLibs
            .where((lib) => lib.isPublic && lib.isDocumented)
            .where(_hasApiElements)
            .where((lib) => !isDuplicateSdkLibrary(lib, allPackageLibs))
            .where((lib) => !isInternalSdkLibrary(lib))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (libraries.isNotEmpty) {
      final rows = <List<String>>[];
      for (final lib in libraries) {
        final link = _markdownLink(lib, paths);
        var libDescription = docs.extractOneLineDoc(lib);
        if (libDescription.isEmpty) {
          libDescription = package.packageMeta.description;
        }
        rows.add([link, libDescription]);
      }

      builder.writeTable(headers: ['Library', 'Description'], rows: rows);
    }
  }

  return builder.toString();
}

/// Renders a library overview page (`api/<dirName>/index.md`).
///
/// Groups elements by kind (Classes, Exceptions, Enums, etc.) with tables
/// using `extractOneLineDoc()` for descriptions.
String renderLibraryPage(
  Library library,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(library);

  builder.writeFrontmatter(
    title: library.name,
    description: 'API documentation for the ${library.name} library',
    outline: [2, 3],
  );

  builder.writeH1(library.name);

  // Library documentation (strip leading H1 if it matches the library name
  // to avoid a duplicate heading, since library doc comments sometimes start
  // with `# LibraryName`).
  var libDoc = docs.processDocumentation(library);
  if (libDoc.isNotEmpty) {
    libDoc = _stripLeadingH1(libDoc, library.name);
    builder.writeParagraph(libDoc);
  }

  // Element groups in specified order
  _renderLibraryOverviewTable(
    builder,
    'Classes',
    library.publicClassesSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Exceptions',
    library.publicExceptionsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Enums',
    library.publicEnumsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Mixins',
    library.publicMixinsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  // Extensions: include "on Type" column
  _renderExtensionsTable(builder, library.publicExtensionsSorted, paths, docs);

  _renderLibraryOverviewTable(
    builder,
    'Extension Types',
    library.publicExtensionTypesSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Functions',
    library.publicFunctionsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Properties',
    library.publicPropertiesSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Constants',
    library.publicConstantsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  _renderLibraryOverviewTable(
    builder,
    'Typedefs',
    library.publicTypedefsSorted.cast<Documentable>(),
    paths,
    docs,
  );

  return builder.toString();
}

/// Renders a class page with all members embedded.
String renderClassPage(
  Class clazz,
  Library library,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(clazz);
  final nameWithGenerics = plainNameWithGenerics(clazz);
  final category = clazz.isErrorOrException ? 'Exceptions' : 'Classes';

  builder.writeFrontmatter(
    title: nameWithGenerics,
    description:
        'API documentation for $nameWithGenerics class from ${library.name}',
    outline: [2, 3],
    outlineCollapsible: _isOutlineCollapsible(clazz),
    category: category,
    library: library.name,
    sourceUrl: clazz.hasSourceHref ? clazz.sourceHrefRaw : null,
  );

  builder.writeH1(
    nameWithGenerics,
    deprecated: clazz.isDeprecated,
    badges: _buildModifierBadges(clazz),
  );

  // Declaration line (linked)
  builder.writeSignature(_buildLinkedContainerDeclaration(clazz, paths));

  // Deprecation notice
  if (clazz.isDeprecated) {
    builder.writeDeprecationNotice(_extractDeprecationMessage(clazz));
  }

  // Annotations
  _renderAnnotations(builder, clazz);

  // Documentation
  final doc = docs.processDocumentation(clazz);
  builder.writeParagraph(doc);

  // Inheritance chain
  _renderInheritanceChain(builder, clazz, paths);

  // Implemented types
  _renderImplementedTypes(builder, clazz, paths);

  // Mixed-in types
  _renderMixedInTypes(builder, clazz, paths);

  // Implementers
  _renderImplementors(builder, clazz, paths);

  // Available Extensions
  _renderAvailableExtensions(builder, clazz, paths);

  // All members
  _renderContainerMembers(builder, clazz, docs, paths);

  return builder.toString();
}

/// Renders an enum page with enum values and all members embedded.
String renderEnumPage(
  Enum enumeration,
  Library library,
  MarkdownPathResolver paths,
  MarkdownDocProcessor docs,
) {
  final builder = _MarkdownPageBuilder();
  paths.currentPageUrl = paths.urlFor(enumeration);
  final nameWithGenerics = plainNameWithGenerics(enumeration);

  builder.writeFrontmatter(
    title: nameWithGenerics,
    description:
        'API documentation for $nameWithGenerics enum from ${library.name}',
    outline: [2, 3],
    outlineCollapsible: _isOutlineCollapsible(enumeration),
    category: 'Enums',
    library: library.name,
    sourceUrl: enumeration.hasSourceHref ? enumeration.sourceHrefRaw : null,
  );

  builder.writeH1(
    nameWithGenerics,
    deprecated: enumeration.isDeprecated,
    badges: _buildModifierBadges(enumeration),
  );

  // Declaration line (linked)
  builder.writeSignature(_buildLinkedContainerDeclaration(enumeration, paths));

  // Deprecation notice
  if (enumeration.isDeprecated) {
    builder.writeDeprecationNotice(_extractDeprecationMessage(enumeration));
  }

  // Annotations
  _renderAnnotations(builder, enumeration);

  // Documentation
  final doc = docs.processDocumentation(enumeration);
  builder.writeParagraph(doc);

  // Inheritance chain
  _renderInheritanceChain(builder, enumeration, paths);

  // Implemented types
  _renderImplementedTypes(builder, enumeration, paths);

  // Mixed-in types
  _renderMixedInTypes(builder, enumeration, paths);

  // Implementers
  _renderImplementors(builder, enumeration, paths);

  // Available Extensions
  _renderAvailableExtensions(builder, enumeration, paths);

  // Enum values section (before other members)
  final enumValues = enumeration.publicEnumValues;
  if (enumValues.isNotEmpty) {
    builder.writeH2('Values');
    for (final value in enumValues) {
      final anchor = 'value-${value.name.toLowerCase()}';
      builder.writeH3WithAnchor(
        value.name,
        anchor: anchor,
        deprecated: value.isDeprecated,
      );
      if (value.isDeprecated) {
        builder.writeDeprecationNotice(_extractDeprecationMessage(value));
      }
      final valueDoc = docs.processDocumentation(value);
      builder.writeParagraph(valueDoc);
    }
  }

  // Standard container members
  _renderContainerMembers(builder, enumeration, docs, paths);

  return builder.toString();
}

/// Renders a mixin page with superclass constraints and all members embedded.