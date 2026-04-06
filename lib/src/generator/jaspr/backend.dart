// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analyzer/file_system/file_system.dart';
import 'package:dartdoc_modern/src/dartdoc_options.dart';
import 'package:dartdoc_modern/src/generator/core/guide_collection.dart'
    as guide_core;
import 'package:dartdoc_modern/src/generator/core/html_sanitizer.dart';
import 'package:dartdoc_modern/src/generator/core/legacy_guide_redirects.dart';
import 'package:dartdoc_modern/src/generator/generator.dart';
import 'package:dartdoc_modern/src/generator/generator_backend.dart';
import 'package:dartdoc_modern/src/generator/jaspr/dart_string.dart';
import 'package:dartdoc_modern/src/generator/jaspr/docs.dart';
import 'package:dartdoc_modern/src/generator/jaspr/paths.dart'
    show JasprPathResolver, isDuplicateSdkLibrary, isInternalSdkLibrary;
import 'package:dartdoc_modern/src/generator/jaspr/scaffold.dart';
import 'package:dartdoc_modern/src/generator/jaspr/search_index.dart';
import 'package:dartdoc_modern/src/generator/jaspr/sidebar.dart'
    show JasprSidebarGenerator;
import 'package:dartdoc_modern/src/generator/template_data.dart';
import 'package:dartdoc_modern/src/generator/templates.dart';
import 'package:dartdoc_modern/src/generator/vitepress/renderer.dart'
    as renderer;
import 'package:dartdoc_modern/src/logging.dart';
import 'package:dartdoc_modern/src/markdown_validator.dart';
import 'package:dartdoc_modern/src/model/model.dart';
import 'package:dartdoc_modern/src/runtime_stats.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// Essential CSS for API documentation pages.
///
/// Written to `web/generated/api_styles.css` on every generation run
/// (not a scaffold file). This ensures existing sites get style updates
/// without requiring users to regenerate their `custom.css`.
const _apiStylesCss = '''
/* Member signature blocks with clickable type links */

.member-signature {
  margin: 4px 0 9px;
}
.member-signature .member-signature-code {
  background: var(--content-pre-bg);
  border-radius: 10px;
  padding: 4px 12px;
  overflow-x: auto;
  white-space: pre-wrap;
  overflow-wrap: break-word;
  margin: 0;
  font-family: var(--content-code-font);
  font-size: 0.92rem;
  color: var(--content-pre-code);
  line-height: 1.08;
}
.member-signature .member-signature-line {
  display: block;
}
/* Shiki-matched syntax highlighting for member signatures.
   Colors from --shiki-light / --shiki-dark CSS variables. */

/* Keywords: const, factory, final, get, set, required, typedef, true, false, null */
.member-signature .kw {
  color: #D73A49;
}
/* Unlinked types: String, int, void, dynamic, type parameters */
.member-signature .type {
  color: #005CC5;
}
/* Linked types (clickable) — same color as .type, underline on hover */
.member-signature .type-link {
  color: #005CC5;
  font-family: inherit;
  font-size: inherit;
  font-weight: 400;
  line-height: inherit;
  text-decoration: underline;
  text-decoration-color: currentColor;
  text-decoration-thickness: 1.5px;
  text-underline-offset: 2px;
}
.member-signature .type-link:hover {
  text-decoration-thickness: 2px;
}
/* Function/method/constructor/field/property names */
.member-signature .fn {
  color: #6F42C1;
}
/* String literals in default values */
.member-signature .str-lit {
  color: #032F62;
}
/* Numeric literals in default values */
.member-signature .num-lit {
  color: #005CC5;
}
/* Dark mode overrides */
.dark .member-signature .kw {
  color: #F97583;
}
.dark .member-signature .type {
  color: #79B8FF;
}
.dark .member-signature .type-link {
  color: #79B8FF;
  text-decoration-color: currentColor;
}
.dark .member-signature .type-link:hover {
  text-decoration-thickness: 2px;
}
.dark .member-signature .fn {
  color: #B392F0;
}
.dark .member-signature .str-lit {
  color: #9ECBFF;
}
.dark .member-signature .num-lit {
  color: #79B8FF;
}

.docs-badge {
  display: inline-flex;
  align-items: center;
  vertical-align: middle;
  margin-left: 0.55rem;
  padding: 0.26rem 0.82rem;
  border-radius: 999px;
  font-size: 0.72em;
  font-weight: 700;
  line-height: 1.2;
  white-space: nowrap;
}
.docs-badge-info {
  background: #eef0f4;
  color: #5f6773;
}
.docs-badge-tip {
  background: #e9defe;
  color: #6b4ff7;
}
.docs-badge-warning {
  background: #fff0cf;
  color: #966300;
}
.dark .docs-badge-info {
  background: #3f3f46;
  color: #d4d4d8;
}
.dark .docs-badge-tip {
  background: #3f2f70;
  color: #d5c6ff;
}
.dark .docs-badge-warning {
  background: #5f4416;
  color: #fde68a;
}

/* API auto-linker — inline code that links to API docs */

a.api-link {
  text-decoration: none;
}

a.api-link code {
  color: var(--content-links);
  border-bottom: 2px solid color-mix(in srgb, var(--content-links) 50%, transparent);
  padding-bottom: 1px;
  transition: color 0.2s, border-color 0.2s;
}

a.api-link:hover code {
  color: var(--content-headings);
  border-bottom-color: var(--content-links);
}
''';

/// Generator backend that produces Jaspr-compatible markdown documentation.
///
/// Extends [GeneratorBackend] to reuse the model traversal loop from
/// [Generator._generateDocs], but overrides ALL 17 `generate*()` methods to
/// produce `.md` files instead of `.html` files.
///
/// Key design decisions:
/// - Never calls `super.generate*()` (super produces HTML via templates).
/// - Passes [_NoOpTemplates] stub to satisfy the base constructor's
///   [Templates] requirement.
/// - Member-level methods (`generateConstructor`, `generateMethod`,
///   `generateProperty`) are no-ops because members are embedded inline
///   on their container's page (class, enum, mixin, extension).
/// - Sidebar is generated in [generatePackage] because it is called first
///   by the traversal and has access to the full [PackageGraph].
/// - Uses [_writeMarkdown] for all file writes; never uses the base class
///   [write] method (which performs `htmlBasePlaceholder` replacement).
class JasprGeneratorBackend extends GeneratorBackend {
  final JasprPathResolver _paths;
  late JasprDocProcessor _docs;
  late JasprSidebarGenerator _sidebar;

  final String _outputPath;
  final String _packageName;
  final String _repositoryUrl;
  final List<String> _guideDirs;
  final List<String> _guideInclude;
  final List<String> _guideExclude;
  final Set<String> _allowedIframeHosts;
  final String? _homePageMarkdown;
  final bool _sdkDocs;

  /// Tracks all file paths written during this generation run.
  ///
  /// Used for incremental generation: after generation completes, files
  /// in the output directory that are NOT in this set can be deleted
  /// as stale artifacts from renamed/removed elements.
  final Set<String> _expectedFiles = {};

  /// Number of files actually written (content changed or new).
  int _writtenCount = 0;

  /// Number of files skipped because content was identical.
  int _unchangedCount = 0;

  JasprGeneratorBackend(
    DartdocGeneratorBackendOptions options,
    FileWriter writer,
    ResourceProvider resourceProvider, {
    required String outputPath,
    required String packageName,
    String repositoryUrl = '',
    List<String> guideDirs = const ['doc', 'docs'],
    List<String> guideInclude = const [],
    List<String> guideExclude = const [],
    List<String> allowedIframeHosts = const [],
    String? homePageMarkdown,
    bool sdkDocs = false,
  }) : _paths = JasprPathResolver(),
       _outputPath = outputPath,
       _packageName = packageName,
       _sdkDocs = sdkDocs,
       _repositoryUrl = repositoryUrl,
       _guideDirs = guideDirs,
       _guideInclude = guideInclude,
       _guideExclude = guideExclude,
       _allowedIframeHosts = Set.of(allowedIframeHosts),
       _homePageMarkdown = homePageMarkdown,
       super(options, _NoOpTemplates(), writer, resourceProvider);

  // ---------------------------------------------------------------------------
  // Lifecycle hooks
  // ---------------------------------------------------------------------------

  @override
  void beforeGenerate(PackageGraph packageGraph) {
    _paths.initFromPackageGraph(packageGraph);
    _docs = JasprDocProcessor(
      packageGraph,
      _paths,
      allowedIframeHosts: _allowedIframeHosts,
    );
    _sidebar = JasprSidebarGenerator(_paths);
  }

  @override
  bool shouldSkipLibrary(
    PackageGraph packageGraph,
    Package package,
    Library library,
    Iterable<Library> allPackageLibraries,
  ) {
    return isDuplicateSdkLibrary(library, allPackageLibraries) ||
        isInternalSdkLibrary(library);
  }

  @override
  void afterGenerate(
    PackageGraph packageGraph,
    List<Documentable> indexedElements,
    List<ModelElement> categorizedElements,
  ) {
    generateSearchIndex(indexedElements);
    generateApiSymbolMap(indexedElements);
    _deleteStaleFiles();
    _logSummary();
  }

  @override
  void validateGeneratedLinks(
    PackageGraph packageGraph,
    DartdocOptionContext config,
    String origin,
    Set<String> writtenFiles,
    StreamController<String> onCheckProgress,
  ) {
    MarkdownValidator(
      packageGraph,
      config,
      origin,
      writtenFiles,
      onCheckProgress,
      anchorStrategy: MarkdownAnchorStrategy.jaspr,
    ).validateLinks();
  }

  // ---------------------------------------------------------------------------
  // Package -- called first by the traversal (generator.dart:86-87).
  // ---------------------------------------------------------------------------

  /// Generates the package overview page and the Jaspr sidebar.
  @override
  void generatePackage(PackageGraph packageGraph, Package package) {
    final isMultiPackage = packageGraph.localPackages.length > 1;

    if (isMultiPackage) {
      logInfo(
        'Generating Jaspr docs for workspace '
        '(${packageGraph.localPackages.length} packages)...',
      );
    } else {
      logInfo('Generating Jaspr docs for package ${package.name}...');
    }

    // Write package/workspace overview page: api/index.md
    String content;
    if (isMultiPackage) {
      content = renderer.renderWorkspaceOverview(packageGraph, _paths, _docs);
    } else {
      content = renderer.renderPackagePage(package, _paths, _docs);
    }
    var filePath = _paths.filePathFor(package);
    if (filePath != null) {
      _writeMarkdown(filePath, content);
    }

    // Generate sidebar from the full PackageGraph.
    var sidebarContent = _sidebar.generateApi(packageGraph);
    _writeMarkdown('lib/generated/api_sidebar.dart', sidebarContent);

    // SDK docs only need API pages -- skip scaffold assets and guides.
    if (!_sdkDocs) {
      // Write essential API styles (always overwritten, not a scaffold file).
      _writeMarkdown('web/generated/api_styles.css', _apiStylesCss);

      // Generate guide files from doc/docs directories.
      final guideCollector = guide_core.GuideCollector(
        resourceProvider: resourceProvider,
        scanDirs: _guideDirs,
        include: _guideInclude,
        exclude: _guideExclude,
      );
      final guideEntries = guideCollector.collectGuideEntries(
        packageGraph: packageGraph,
        isMultiPackage: isMultiPackage,
        transformContent: (content, _, sourcePath) {
          final expandedImports = _expandCodeImports(content, sourcePath);
          final withoutTocDirective = expandedImports.replaceAll(
            RegExp(r'^\[TOC\]\s*$', multiLine: true),
            '',
          );
          return sanitizeHtml(
            withoutTocDirective,
            extraAllowedHosts: _allowedIframeHosts,
          );
        },
      );
      final rewrittenGuideEntries = rewriteGuideLinksForJaspr(guideEntries);

      // Write guide files through _writeMarkdown for incremental checks.
      for (final entry in rewrittenGuideEntries) {
        _writeMarkdown(entry.relativePath, entry.content);
      }

      _writeMarkdown('web/index.html', _buildRootIndexHtml());
      _writeMarkdown('web/404.html', _buildRootIndexHtml());

      var guideSidebarContent = _sidebar.generateGuide(
        rewrittenGuideEntries,
        isMultiPackage: isMultiPackage,
      );
      _writeMarkdown('lib/generated/guide_sidebar.dart', guideSidebarContent);

      if (_homePageMarkdown case final homePageMarkdown?) {
        _writeMarkdown('content/index.md', homePageMarkdown);
      }
    }

    runtimeStats.incrementAccumulator('writtenPackageFileCount');
  }

  // ---------------------------------------------------------------------------
  // Category
  // ---------------------------------------------------------------------------

  /// Generates a category (topic) page.
  ///
  /// Output: `topics/<CategoryName>.md`
  ///
  /// Unlike the HTML backend, no redirect file is generated -- Jaspr
  /// handles clean URLs natively.
  @override
  void generateCategory(PackageGraph packageGraph, Category category) {
    logInfo(
      'Generating docs for category ${category.name} '
      'from ${category.package.fullyQualifiedName}...',
    );

    var content = renderer.renderCategoryPage(category, _paths, _docs);
    var filePath = _paths.filePathFor(category);
    if (filePath != null) {
      _writeMarkdown(filePath, content);
    }

    runtimeStats.incrementAccumulator('writtenCategoryFileCount');
  }

  // ---------------------------------------------------------------------------
  // Library
  // ---------------------------------------------------------------------------

  /// Generates the library overview page.
  ///
  /// Output: `api/<dirName>/index.md`
  ///
  /// No redirect file is generated (the HTML backend writes one for the
  /// old library path; Jaspr does not need this).
  @override
  void generateLibrary(PackageGraph packageGraph, Library library) {
    logInfo('Generating docs for library ${library.name}...');

    var content = renderer.renderLibraryPage(library, _paths, _docs);
    var filePath = _paths.filePathFor(library);
    if (filePath != null) {
      _writeMarkdown(filePath, content);
    }

    runtimeStats.incrementAccumulator('writtenLibraryFileCount');
  }

  // ---------------------------------------------------------------------------
  // Container-level: Class, Enum, Mixin, Extension, ExtensionType
  //
  // Each produces ONE markdown file with all members inlined as sections.
  // ---------------------------------------------------------------------------

  /// Generates a class page with all members (constructors, properties,
  /// methods, operators) embedded as sections.
  ///
  /// Output: `api/<dirName>/<ClassName>.md`
  @override
  void generateClass(PackageGraph packageGraph, Library library, Class class_) {
    try {
      var content = renderer.renderClassPage(class_, library, _paths, _docs);
      var filePath = _paths.filePathFor(class_);
      if (filePath != null) {
        _writeMarkdown(filePath, content);
      }
    } on Object catch (e) {
      logWarning('Failed to generate page for class ${class_.name}: $e');
    }

    runtimeStats.incrementAccumulator('writtenClassFileCount');
  }

  /// Generates an enum page with enum values and all members embedded.
  ///
  /// Output: `api/<dirName>/<EnumName>.md`
  @override
  void generateEnum(PackageGraph packageGraph, Library library, Enum enum_) {
    try {
      var content = renderer.renderEnumPage(enum_, library, _paths, _docs);
      var filePath = _paths.filePathFor(enum_);
      if (filePath != null) {
        _writeMarkdown(filePath, content);
      }
    } on Object catch (e) {
      logWarning('Failed to generate page for enum ${enum_.name}: $e');
    }

    runtimeStats.incrementAccumulator('writtenEnumFileCount');
  }

  /// Generates a mixin page with superclass constraints and all members.
  ///
  /// Output: `api/<dirName>/<MixinName>.md`
  @override
  void generateMixin(PackageGraph packageGraph, Library library, Mixin mixin) {
    try {
      var content = renderer.renderMixinPage(mixin, library, _paths, _docs);
      var filePath = _paths.filePathFor(mixin);
      if (filePath != null) {
        _writeMarkdown(filePath, content);
      }
    } on Object catch (e) {
      logWarning('Failed to generate page for mixin ${mixin.name}: $e');
    }

    runtimeStats.incrementAccumulator('writtenMixinFileCount');
  }

  /// Generates an extension page with extended type and all members.
  ///
  /// Output: `api/<dirName>/<ExtensionName>.md`
  @override
  void generateExtension(
    PackageGraph packageGraph,
    Library library,
    Extension extension,
  ) {
    try {
      var content = renderer.renderExtensionPage(
        extension,
        library,
        _paths,
        _docs,
      );
      var filePath = _paths.filePathFor(extension);
      if (filePath != null) {
        _writeMarkdown(filePath, content);
      }
    } on Object catch (e) {
      logWarning('Failed to generate page for extension ${extension.name}: $e');
    }

    runtimeStats.incrementAccumulator('writtenExtensionFileCount');
  }

  /// Generates an extension type page with representation type and all
  /// members.
  ///
  /// Output: `api/<dirName>/<ExtensionTypeName>.md`
  @override
  void generateExtensionType(
    PackageGraph packageGraph,
    Library library,
    ExtensionType extensionType,
  ) {
    try {
      var content = renderer.renderExtensionTypePage(
        extensionType,
        library,
        _paths,
        _docs,
      );
      var filePath = _paths.filePathFor(extensionType);
      if (filePath != null) {
        _writeMarkdown(filePath, content);
      }
    } on Object catch (e) {
      logWarning(
        'Failed to generate page for extension type ${extensionType.name}: $e',
      );
    }

    runtimeStats.incrementAccumulator('writtenExtensionTypeFileCount');
  }

  // ---------------------------------------------------------------------------
  // Top-level elements: Function, Property, Typedef
  //
  // Each produces one page per element.
  // ---------------------------------------------------------------------------

  /// Generates a top-level function page.
  ///
  /// Output: `api/<dirName>/<FunctionName>.md`
  @override
  void generateFunction(
    PackageGraph packageGraph,
    Library library,
    ModelFunction function,
  ) {
    try {
      var content = renderer.renderFunctionPage(
        function,
        library,
        _paths,
        _docs,
      );
      var filePath = _paths.filePathFor(function);
      if (filePath != null) {
        _writeMarkdown(filePath, content);
      }
    } on Object catch (e) {
      logWarning('Failed to generate page for function ${function.name}: $e');
    }

    runtimeStats.incrementAccumulator('writtenFunctionFileCount');
  }

  /// Generates a top-level property or constant page.
  ///
  /// Output: `api/<dirName>/<PropertyName>.md`
  @override
  void generateTopLevelProperty(
    PackageGraph packageGraph,
    Library library,
    TopLevelVariable property,
  ) {
    try {
      var content = renderer.renderPropertyPage(
        property,
        library,
        _paths,
        _docs,
      );
      var filePath = _paths.filePathFor(property);
      if (filePath != null) {
        _writeMarkdown(filePath, content);
      }
    } on Object catch (e) {
      logWarning('Failed to generate page for property ${property.name}: $e');
    }

    runtimeStats.incrementAccumulator('writtenTopLevelPropertyFileCount');
  }

  /// Generates a typedef page.
  ///
  /// Output: `api/<dirName>/<TypedefName>.md`
  @override
  void generateTypeDef(
    PackageGraph packageGraph,
    Library library,
    Typedef typedef,
  ) {
    try {
      var content = renderer.renderTypedefPage(typedef, library, _paths, _docs);
      var filePath = _paths.filePathFor(typedef);
      if (filePath != null) {
        _writeMarkdown(filePath, content);
      }
    } on Object catch (e) {
      logWarning('Failed to generate page for typedef ${typedef.name}: $e');
    }

    runtimeStats.incrementAccumulator('writtenTypedefFileCount');
  }

  // ---------------------------------------------------------------------------
  // Member-level methods -- NO-OPs.
  //
  // Members (constructors, methods, properties, operators) are embedded
  // directly on their container's page as anchored sections. The traversal
  // in generator.dart still calls these methods, but we intentionally
  // produce no output.
  // ---------------------------------------------------------------------------

  /// No-op: constructors are rendered inline on the class/enum page.
  @override
  void generateConstructor(
    PackageGraph packageGraph,
    Library library,
    Constructable constructable,
    Constructor constructor,
  ) {
    // Intentionally empty -- constructors are embedded on the container page.
  }

  /// No-op: methods are rendered inline on the container page.
  @override
  void generateMethod(
    PackageGraph packageGraph,
    Library library,
    Container container,
    Method method,
  ) {
    // Intentionally empty -- methods are embedded on the container page.
  }

  /// No-op: properties/fields are rendered inline on the container page.
  @override
  void generateProperty(
    PackageGraph packageGraph,
    Library library,
    Container container,
    Field field,
  ) {
    // Intentionally empty -- properties are embedded on the container page.
  }

  // ---------------------------------------------------------------------------
  // Infrastructure -- NO-OPs for Jaspr.
  // ---------------------------------------------------------------------------

  /// Generates a static JSON search index for the Jaspr scaffold runtime.
  @override
  void generateSearchIndex(List<Documentable> indexedElements) {
    final builder = JasprSearchIndexBuilder(
      resourceProvider: resourceProvider,
      outputPath: _outputPath,
    );
    final output = builder.build(_expectedFiles);
    _writeMarkdown('web/generated/search_index.json', output.manifestJson);
    _writeMarkdown('web/generated/search_pages.json', output.pagesJson);
    _writeMarkdown('web/generated/search_sections.json', output.sectionsJson);
    _writeMarkdown(
      'web/generated/search_sections_content.json',
      output.sectionsContentJson,
    );
  }

  void generateApiSymbolMap(List<Documentable> indexedElements) {
    final apiEntries = _collectApiSymbolEntries(indexedElements);
    final buffer = StringBuffer()
      ..writeln('// Generated by dartdoc_modern. Do not edit.')
      ..writeln()
      ..writeln('class ApiSymbolEntry {')
      ..writeln('  final String href;')
      ..writeln('  final String relativePath;')
      ..writeln('  final String apiDir;')
      ..writeln()
      ..writeln('  const ApiSymbolEntry({')
      ..writeln('    required this.href,')
      ..writeln('    required this.relativePath,')
      ..writeln('    required this.apiDir,')
      ..writeln('  });')
      ..writeln('}')
      ..writeln()
      ..writeln('const apiSymbolMap = <String, List<ApiSymbolEntry>>{');

    final symbolNames = apiEntries.keys.toList()..sort();
    for (final symbolName in symbolNames) {
      final entries = apiEntries[symbolName]!
        ..sort((a, b) {
          final dirCompare = a.apiDir.compareTo(b.apiDir);
          if (dirCompare != 0) return dirCompare;
          return a.relativePath.compareTo(b.relativePath);
        });
      buffer.writeln("  '${escapeDartSingleQuotedString(symbolName)}': [");
      for (final entry in entries) {
        buffer.writeln(
          "    ApiSymbolEntry(href: '${escapeDartSingleQuotedString(entry.href)}', relativePath: '${escapeDartSingleQuotedString(entry.relativePath)}', apiDir: '${escapeDartSingleQuotedString(entry.apiDir)}'),",
        );
      }
      buffer.writeln('  ],');
    }

    buffer.writeln('};');

    _writeMarkdown('lib/generated/api_symbols.dart', buffer.toString());
  }

  /// No-op: category JSON is only used by the HTML frontend.
  @override
  void generateCategoryJson(List<ModelElement> categorizedElements) {
    // Intentionally empty -- not needed for Jaspr.
  }

  /// Called BEFORE the traversal at `generator.dart:49`.
  ///
  /// Creates Jaspr scaffold files (`pubspec.yaml`, `main.server.dart`,
  /// `main.client.dart`, `content/index.md`) if they don't already exist.
  /// These are one-time setup files that the user may customize afterwards.
  @override
  Future<void> generateAdditionalFiles() async {
    // SDK docs don't need Jaspr scaffold files (pubspec.yaml, app.dart, etc.)
    // -- the output is pure content, not a standalone Jaspr project.
    if (_sdkDocs) return;

    var initGenerator = JasprInitGenerator(
      writer: writer,
      resourceProvider: resourceProvider,
      outputPath: _outputPath,
    );
    await initGenerator.generate(
      packageName: _packageName,
      repositoryUrl: _repositoryUrl,
    );
  }

  // ---------------------------------------------------------------------------
  // File writing
  // ---------------------------------------------------------------------------

  /// Writes markdown content to the output directory (incremental).
  // Pre-compiled patterns for VitePress syntax stripping.
  static final _vitepressFrontmatterLine = RegExp(r'^(editLink|prev|next):.*$');
  static final _apiBreadcrumbLine = RegExp(r'^\s*<ApiBreadcrumb\s*/?>\s*$');
  static final _tocMarkerLine = RegExp(r'^\s*\[\[toc\]\]\s*$');
  static final _badgeComponent = RegExp(r'<Badge\b[^>]*/>');
  static final _badgeAttribute = RegExp(r'([A-Za-z][A-Za-z0-9_-]*)="([^"]*)"');
  static final _codeFenceLine = RegExp(r'^\s*(```|~~~)');
  static final _codeImportLine = RegExp(r'^<<<\s+(.+?)\s*$');
  static final _codeImportSpec = RegExp(
    r'^(?<path>[^#]+?)(?:#L(?<start>\d+)(?:-L?(?<end>\d+))?)?$',
  );
  static final _markdownLinkPattern = RegExp(r'(!?\[[^\]]*\]\()([^)]+)(\))');
  static final _frontMatterFence = RegExp(r'^---\s*$');
  static final _headingPattern = RegExp(r'^\s{0,3}#{1,6}\s+(.*?)\s*$');
  static final _explicitHeadingAnchor = RegExp(
    r'\s+\{#([A-Za-z0-9:_\-.]+)\}\s*$',
  );
  static final _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');

  /// Strips VitePress-specific syntax from markdown so Jaspr renders cleanly.
  @visibleForTesting
  static String stripVitePressSyntaxForJaspr(String content) {
    final lines = content.split('\n');
    final output = <String>[];
    var index = 0;

    if (lines.isNotEmpty && lines.first.trim() == '---') {
      output.add(lines.first);
      index = 1;

      for (; index < lines.length; index++) {
        final line = lines[index];
        if (line.trim() == '---') {
          while (output.length > 1 && output.last.trim().isEmpty) {
            output.removeLast();
          }
          output.add(line);
          index++;
          break;
        }
        if (_vitepressFrontmatterLine.hasMatch(line)) {
          continue;
        }
        output.add(line);
      }
    }

    var inCodeFence = false;
    for (; index < lines.length; index++) {
      var line = lines[index];

      if (!inCodeFence && _apiBreadcrumbLine.hasMatch(line)) {
        continue;
      }

      if (!inCodeFence) {
        if (_tocMarkerLine.hasMatch(line)) {
          continue;
        }

        if (_badgeComponent.hasMatch(line)) {
          line = _replaceVitePressBadges(line);
        }
      }

      output.add(line);

      if (_codeFenceLine.hasMatch(line)) {
        inCodeFence = !inCodeFence;
      }
    }

    var result = output.join('\n');
    result = result.replaceAll(r'\{\{', '{{');
    result = result.replaceAll(r'\}\}', '}}');
    result = result.replaceFirst(RegExp(r'^\n+'), '');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return result;
  }

  static String _replaceVitePressBadges(String line) {
    return line
        .replaceAllMapped(_badgeComponent, _renderJasprBadge)
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trimRight();
  }

  static String _renderJasprBadge(Match match) {
    final attrs = <String, String>{};
    for (final attr in _badgeAttribute.allMatches(match.group(0)!)) {
      attrs[attr.group(1)!] = attr.group(2)!;
    }

    final text = attrs['text']?.trim();
    if (text == null || text.isEmpty) {
      return '';
    }

    final type = switch (attrs['type']?.trim()) {
      'tip' => 'tip',
      'warning' => 'warning',
      _ => 'info',
    };

    return '<span class="docs-badge docs-badge-$type">${_escapeInlineHtml(text)}</span>';
  }

  static String _escapeInlineHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _expandCodeImports(String content, String sourcePath) {
    final sourceDir = p.dirname(sourcePath);
    final lines = content.split('\n');
    final output = <String>[];
    var inCodeFence = false;

    for (final line in lines) {
      if (_codeFenceLine.hasMatch(line)) {
        inCodeFence = !inCodeFence;
        output.add(line);
        continue;
      }

      if (!inCodeFence) {
        final match = _codeImportLine.firstMatch(line.trim());
        if (match != null) {
          final expanded = _readImportedCode(match.group(1)!, sourceDir);
          if (expanded != null) {
            output.add(expanded.trimRight());
            output.add('');
            continue;
          }
        }
      }

      output.add(line);
    }

    return output.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  String? _readImportedCode(String spec, String sourceDir) {
    final match = _codeImportSpec.firstMatch(spec.trim());
    if (match == null) return null;

    final importPath = match.namedGroup('path')!.trim();
    final fullPath = p.normalize(p.join(sourceDir, importPath));
    final file = resourceProvider.getFile(fullPath);
    if (!file.exists) {
      logWarning('Guide code import not found: $importPath');
      return null;
    }

    final startLine = int.tryParse(match.namedGroup('start') ?? '');
    final endLine = int.tryParse(match.namedGroup('end') ?? '');
    final fileLines = file.readAsStringSync().split('\n');

    var selectedLines = fileLines;
    if (startLine != null) {
      final normalizedStart = startLine.clamp(1, fileLines.length);
      final normalizedEnd = (endLine ?? startLine).clamp(
        normalizedStart,
        fileLines.length,
      );
      selectedLines = fileLines.sublist(normalizedStart - 1, normalizedEnd);
    }

    final extension = p.extension(importPath).replaceFirst('.', '').trim();
    final language = extension.isEmpty ? 'text' : extension;
    return '```$language\n${selectedLines.join('\n')}\n```';
  }

  /// Remaps VitePress-style paths to Jaspr content/ directory.
  ///
  /// `api/dart-core/index.md` -> `content/api/dart-core/index.md`
  /// `guide/intro.md` -> `content/guide/intro.md`
  /// `topics/category.md` -> `content/topics/category.md`
  /// `lib/generated/api_sidebar.dart` -> unchanged
  static String _remapToContentDir(String filePath) {
    if (filePath.startsWith('api/') ||
        filePath.startsWith('guide/') ||
        filePath.startsWith('topics/')) {
      return 'content/$filePath';
    }
    return filePath;
  }

  String _buildRootIndexHtml() {
    final assetVersion = DateTime.now().millisecondsSinceEpoch;
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${_escapeHtml(_packageName)} API</title>
    <link rel="icon" href="favicon.svg" type="image/svg+xml">
    <link rel="stylesheet" href="generated/api_styles.css?v=$assetVersion">
    <script>
      const storedTheme = window.localStorage.getItem('jaspr:theme');
      const resolvedTheme = storedTheme ??
          (window.matchMedia('(prefers-color-scheme: dark)').matches
              ? 'dark'
              : 'light');
      document.documentElement.setAttribute('data-theme', resolvedTheme);
    </script>
  </head>
  <body>
    <p>Loading documentation...</p>
    <script src="main.client.dart.js?v=$assetVersion" defer></script>
  </body>
</html>
''';
  }

  @visibleForTesting
  static List<guide_core.GuideEntry> rewriteGuideLinksForJaspr(
    List<guide_core.GuideEntry> entries,
  ) {
    if (entries.isEmpty) return entries;

    final routeByRelativePath = <String, String>{
      for (final entry in entries)
        entry.relativePath: _guideRouteForRelativePath(entry.relativePath),
    };
    final relativePathByRoute = <String, String>{
      for (final entry in entries)
        _guideRouteForRelativePath(entry.relativePath): entry.relativePath,
    };
    final anchorMapByRelativePath = <String, Map<String, String>>{
      for (final entry in entries)
        entry.relativePath: _buildJasprAnchorRewriteMap(entry.content),
    };
    final jasprAnchorsByRelativePath = <String, Set<String>>{
      for (final entry in entries)
        entry.relativePath: _extractJasprHeadingAnchors(entry.content).toSet(),
    };

    return [
      for (final entry in entries)
        guide_core.GuideEntry(
          packageName: entry.packageName,
          relativePath: entry.relativePath,
          title: entry.title,
          content: _rewriteGuideMarkdownLinks(
            entry.content,
            currentRelativePath: entry.relativePath,
            routeByRelativePath: routeByRelativePath,
            relativePathByRoute: relativePathByRoute,
            anchorMapByRelativePath: anchorMapByRelativePath,
            jasprAnchorsByRelativePath: jasprAnchorsByRelativePath,
          ),
          sourcePath: entry.sourcePath,
          sidebarPosition: entry.sidebarPosition,
        ),
    ];
  }

  static String _rewriteGuideMarkdownLinks(
    String content, {
    required String currentRelativePath,
    required Map<String, String> routeByRelativePath,
    required Map<String, String> relativePathByRoute,
    required Map<String, Map<String, String>> anchorMapByRelativePath,
    required Map<String, Set<String>> jasprAnchorsByRelativePath,
  }) {
    return content.replaceAllMapped(_markdownLinkPattern, (match) {
      final prefix = match.group(1)!;
      final destination = match.group(2)!;
      final suffix = match.group(3)!;

      final rewritten = _rewriteGuideDestination(
        destination,
        currentRelativePath: currentRelativePath,
        routeByRelativePath: routeByRelativePath,
        relativePathByRoute: relativePathByRoute,
        anchorMapByRelativePath: anchorMapByRelativePath,
        jasprAnchorsByRelativePath: jasprAnchorsByRelativePath,
      );

      return '$prefix$rewritten$suffix';
    });
  }

  static String _rewriteGuideDestination(
    String destination, {
    required String currentRelativePath,
    required Map<String, String> routeByRelativePath,
    required Map<String, String> relativePathByRoute,
    required Map<String, Map<String, String>> anchorMapByRelativePath,
    required Map<String, Set<String>> jasprAnchorsByRelativePath,
  }) {
    final trimmed = destination.trim();
    if (trimmed.isEmpty || _schemePattern.hasMatch(trimmed)) return destination;
    if (trimmed.startsWith('//')) return destination;

    final hashIndex = trimmed.indexOf('#');
    final pathPart = hashIndex == -1
        ? trimmed
        : trimmed.substring(0, hashIndex);
    final fragment = hashIndex == -1 ? null : trimmed.substring(hashIndex + 1);

    String rewriteFragment(String relativePath, String? currentFragment) {
      if (currentFragment == null || currentFragment.isEmpty) return '';
      final anchorMap = anchorMapByRelativePath[relativePath];
      final jasprAnchors = jasprAnchorsByRelativePath[relativePath] ?? const {};
      final normalizedLegacy = _normalizeLegacyGuideAnchor(currentFragment);
      final rewritten = jasprAnchors.contains(currentFragment)
          ? currentFragment
          : jasprAnchors.contains(normalizedLegacy)
          ? normalizedLegacy
          : anchorMap?[currentFragment] ??
                anchorMap?[normalizedLegacy] ??
                currentFragment;
      return '#$rewritten';
    }

    if (pathPart.isEmpty) {
      final currentRoute =
          routeByRelativePath[currentRelativePath] ??
          _guideRouteForRelativePath(currentRelativePath);
      return '$currentRoute${rewriteFragment(currentRelativePath, fragment)}';
    }

    if (pathPart.startsWith('/')) {
      final normalizedRoute = p.posix.normalize(pathPart);
      final rootedMarkdownPath = normalizedRoute.startsWith('/')
          ? normalizedRoute.substring(1)
          : normalizedRoute;
      final targetRelativePath =
          relativePathByRoute[normalizedRoute] ??
          (p.posix.extension(rootedMarkdownPath) == '.md'
              ? rootedMarkdownPath
              : null);
      if (targetRelativePath == null) return destination;
      final route = routeByRelativePath[targetRelativePath] ?? normalizedRoute;
      return '$route${rewriteFragment(targetRelativePath, fragment)}';
    }

    final currentDir = p.posix.dirname(currentRelativePath);
    final relativeFile = p.posix.normalize(p.posix.join(currentDir, pathPart));
    if (p.posix.extension(relativeFile) != '.md') return destination;

    final route = routeByRelativePath[relativeFile];
    if (route == null) return destination;
    return '$route${rewriteFragment(relativeFile, fragment)}';
  }

  static String _guideRouteForRelativePath(String relativePath) {
    var route = '/${relativePath.replaceAll('.md', '')}';
    if (route.endsWith('/index')) {
      route = route.substring(0, route.length - '/index'.length);
      return route.isEmpty ? '/' : route;
    }
    return route;
  }

  static String _normalizeLegacyGuideAnchor(String fragment) {
    final trimmed = fragment.trim();
    if (trimmed.isEmpty) return trimmed;

    final withoutUnderscore = trimmed.startsWith('_')
        ? trimmed.substring(1)
        : trimmed;
    final numberedPrefix = RegExp(
      r'^(\d+(?:-\d+)+)(-.+)$',
    ).firstMatch(withoutUnderscore);
    if (numberedPrefix == null) return withoutUnderscore;

    final compactNumber = numberedPrefix.group(1)!.replaceAll('-', '');
    final suffix = numberedPrefix.group(2)!;
    return '$compactNumber$suffix';
  }

  static Map<String, String> _buildJasprAnchorRewriteMap(String content) {
    final sourceAnchors = _extractSourceHeadingAnchors(content);
    final jasprAnchors = _extractJasprHeadingAnchors(content);
    final anchorMap = <String, String>{};
    final pairCount = sourceAnchors.length < jasprAnchors.length
        ? sourceAnchors.length
        : jasprAnchors.length;

    for (var i = 0; i < pairCount; i++) {
      final sourceAnchor = sourceAnchors[i];
      final jasprAnchor = jasprAnchors[i];
      if (sourceAnchor.isEmpty || jasprAnchor.isEmpty) continue;
      anchorMap[sourceAnchor] = jasprAnchor;
      if (RegExp(r'^\d').hasMatch(sourceAnchor)) {
        anchorMap['_$sourceAnchor'] = jasprAnchor;
      }
    }

    return anchorMap;
  }

  static List<String> _extractSourceHeadingAnchors(String content) {
    final anchors = <String>[];
    var inFrontMatter = false;
    var frontMatterHandled = false;
    var inFence = false;

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (!frontMatterHandled && _frontMatterFence.hasMatch(trimmed)) {
        inFrontMatter = !inFrontMatter;
        if (!inFrontMatter) {
          frontMatterHandled = true;
        }
        continue;
      }
      if (inFrontMatter) continue;

      if (_codeFenceLine.hasMatch(line)) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;

      final headingMatch = _headingPattern.firstMatch(line);
      if (headingMatch == null) continue;

      final rawHeading = headingMatch.group(1)!.trim();
      final explicitAnchor = _explicitHeadingAnchor.firstMatch(rawHeading);
      if (explicitAnchor != null) {
        anchors.add(explicitAnchor.group(1)!);
        continue;
      }

      final headingText = rawHeading.replaceFirst(_explicitHeadingAnchor, '');
      final sanitized = JasprPathResolver.sanitizeAnchor(headingText);
      if (sanitized.isNotEmpty) {
        anchors.add(sanitized);
      }
    }

    return anchors;
  }

  static List<String> _extractJasprHeadingAnchors(String content) {
    final document = _buildJasprMarkdownDocument();
    final nodes = document.parse(content);
    final anchors = <String>[];

    void visit(md.Node node) {
      if (node is! md.Element) return;

      if (RegExp(r'^h[1-6]$').hasMatch(node.tag)) {
        final generatedId = node.generatedId;
        if (generatedId != null && generatedId.isNotEmpty) {
          anchors.add(generatedId);
        }
      }

      for (final child in node.children ?? const <md.Node>[]) {
        visit(child);
      }
    }

    for (final node in nodes) {
      visit(node);
    }

    return anchors;
  }

  static md.Document _buildJasprMarkdownDocument() {
    return md.Document(
      blockSyntaxes: const [
        md.HeaderWithIdSyntax(),
        md.SetextHeaderWithIdSyntax(),
      ],
      extensionSet: md.ExtensionSet.gitHubWeb,
    );
  }

  Map<String, List<_ApiSymbolEntry>> _collectApiSymbolEntries(
    List<Documentable> indexedElements,
  ) {
    final entries = _collectPageApiSymbolEntries();

    for (final documentable in indexedElements) {
      if (documentable is! ModelElement) continue;
      _appendQualifiedApiSymbolEntry(entries, documentable);
      if (documentable is Enum) {
        for (final enumValue in documentable.publicEnumValues) {
          _appendQualifiedApiSymbolEntry(entries, enumValue);
        }
      }
    }

    return entries;
  }

  Map<String, List<_ApiSymbolEntry>> _collectPageApiSymbolEntries() {
    final apiRoot = p.join(_outputPath, 'content', 'api');
    final folder = resourceProvider.getFolder(apiRoot);
    if (!folder.exists) return const {};

    final entries = <String, List<_ApiSymbolEntry>>{};

    void visit(Folder current) {
      for (final child in current.getChildren()) {
        if (child is Folder) {
          visit(child);
          continue;
        }
        if (child is! File || !child.path.endsWith('.md')) continue;

        final relativeFromOutput = p.relative(
          child.path,
          from: p.normalize(_outputPath),
        );
        final normalizedRelative = p.posix.joinAll(p.split(relativeFromOutput));
        if (!normalizedRelative.startsWith('content/api/')) continue;

        final relativePath = normalizedRelative.replaceFirst(
          RegExp(r'^content/'),
          '',
        );
        if (relativePath.endsWith('/index.md') ||
            relativePath.endsWith('/library.md') ||
            relativePath == 'api/index.md') {
          continue;
        }

        final symbolName = p.basenameWithoutExtension(relativePath);
        final href = '/${relativePath.replaceFirst('.md', '')}';
        final apiDir = _apiDirForRelativePath(relativePath);

        _appendApiSymbolEntry(
          entries,
          symbolName,
          _ApiSymbolEntry(
            href: href,
            relativePath: relativePath,
            apiDir: apiDir,
          ),
        );
      }
    }

    visit(folder);
    return entries;
  }

  void _appendApiSymbolEntry(
    Map<String, List<_ApiSymbolEntry>> entries,
    String symbolName,
    _ApiSymbolEntry entry,
  ) {
    final bucket = entries.putIfAbsent(symbolName, () => []);
    final duplicate = bucket.any(
      (candidate) =>
          candidate.href == entry.href &&
          candidate.relativePath == entry.relativePath &&
          candidate.apiDir == entry.apiDir,
    );
    if (!duplicate) {
      bucket.add(entry);
    }
  }

  void _appendQualifiedApiSymbolEntry(
    Map<String, List<_ApiSymbolEntry>> entries,
    ModelElement element,
  ) {
    final qualifiedName = _qualifiedApiSymbolNameFor(element);
    if (qualifiedName == null) return;
    final href = _paths.linkFor(element);
    final relativePath = _relativeApiPagePathFor(element);
    if (href == null || relativePath == null) return;
    _appendApiSymbolEntry(
      entries,
      qualifiedName,
      _ApiSymbolEntry(
        href: href,
        relativePath: relativePath,
        apiDir: _apiDirForRelativePath(relativePath),
      ),
    );
  }

  String? _qualifiedApiSymbolNameFor(ModelElement element) {
    final href = _paths.linkFor(element);
    if (href == null || !href.startsWith('/api/')) return null;

    final ownerName = _apiSymbolOwnerName(element);
    final memberName = _apiSymbolMemberName(element);
    if (ownerName == null || ownerName.isEmpty) return null;
    if (memberName == null || memberName.isEmpty) return null;
    return '$ownerName.$memberName';
  }

  String? _apiSymbolOwnerName(ModelElement element) {
    final enclosing = element.enclosingElement;
    return switch (enclosing) {
      final Library library => library.name,
      final ModelElement model => model.name,
      _ => null,
    };
  }

  String? _apiSymbolMemberName(ModelElement element) {
    if (element is Container) return null;
    if (element is Constructor) {
      return element.isUnnamedConstructor ? null : element.name;
    }
    if (element is Operator) {
      return 'operator ${element.referenceName}';
    }
    if (element is Accessor) {
      final name = element.name;
      return name.endsWith('=') ? name.substring(0, name.length - 1) : name;
    }
    return element.name;
  }

  String? _relativeApiPagePathFor(Documentable element) {
    final pageElement = _pageDocumentableFor(element);
    if (pageElement == null) return null;
    final filePath = _paths.filePathFor(pageElement);
    if (filePath == null) return null;
    var normalized = p.posix.joinAll(p.split(filePath));
    if (normalized.startsWith('content/')) {
      normalized = normalized.replaceFirst(RegExp(r'^content/'), '');
    }
    return normalized.startsWith('api/') ? normalized : null;
  }

  Documentable? _pageDocumentableFor(Documentable element) {
    final directFilePath = _paths.filePathFor(element);
    if (directFilePath != null) return element;
    if (element case ModelElement(:final enclosingElement)) {
      return enclosingElement is Documentable ? enclosingElement : null;
    }
    return null;
  }

  String _apiDirForRelativePath(String relativePath) {
    final parts = relativePath.split('/');
    return parts.length >= 2 ? parts[1] : '';
  }

  String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  ///
  /// Tracks the file path in [_expectedFiles] for manifest-based stale file
  /// deletion. Compares new content against the existing file on disk and
  /// skips the write if identical, incrementing [_unchangedCount] instead
  /// of [_writtenCount].
  void _writeMarkdown(String filePath, String content) {
    // Jaspr expects markdown content in content/ directory.
    final jasprPath = _remapToContentDir(filePath);

    // Strip VitePress-specific syntax from markdown content.
    if (jasprPath.endsWith('.md')) {
      content = stripVitePressSyntaxForJaspr(content);
    }

    _writeGeneratedFile(jasprPath, content);
  }

  void _writeGeneratedFile(String filePath, String content) {
    _expectedFiles.add(filePath);

    // Incremental generation: skip write if content is unchanged.
    // Normalize the path: filePath uses POSIX separators (/) but on Windows
    // _outputPath uses backslashes. p.normalize resolves mixed separators.
    final fullPath = p.normalize(p.join(_outputPath, filePath));
    final existingFile = resourceProvider.getFile(fullPath);
    if (existingFile.exists) {
      try {
        if (existingFile.readAsStringSync() == content) {
          _unchangedCount++;
          return;
        }
      } on FileSystemException {
        // If we can't read the file, fall through to write.
      }
    }

    writer.write(filePath, content);
    _writtenCount++;
  }

  // ---------------------------------------------------------------------------
  // Stale file cleanup
  // ---------------------------------------------------------------------------

  /// Number of stale files deleted during cleanup.
  int _deletedCount = 0;

  /// Scans output directories and deletes files not in [_expectedFiles].
  ///
  /// Only deletes `.md` files under `api/` and `guide/` subdirectories,
  /// `.dart` files under `lib/generated/`, and static runtime assets under
  /// `web/generated/`.
  /// Files in the `guide/` root are preserved (scaffold and user files).
  void _deleteStaleFiles() {
    _deletedCount = 0;
    _deleteStaleInDir('content/api', '.md');
    _deleteStaleInDir('content/guide', '.md', null, true);
    _deleteStaleLegacyGuideRedirects('web/guide');
    _deleteStaleInDir(p.join('lib', 'generated'), '.dart');
    _deleteStaleInDir(p.join('web', 'generated'), '.css');
    _deleteStaleInDir(p.join('web', 'generated'), '.json');
  }

  void _deleteStaleLegacyGuideRedirects(
    String dirRelative, [
    Set<String>? visited,
  ]) {
    visited ??= {};
    final pathContext = resourceProvider.pathContext;
    final dirPath = pathContext.normalize(
      pathContext.join(_outputPath, dirRelative),
    );
    if (!visited.add(dirPath)) return;

    final folder = resourceProvider.getFolder(dirPath);
    if (!folder.exists) return;

    for (final child in folder.getChildren()) {
      if (child is Folder) {
        final relativePath = pathContext.relative(
          child.path,
          from: _outputPath,
        );
        _deleteStaleLegacyGuideRedirects(relativePath, visited);
        continue;
      }

      final relativePath = p.posix.joinAll(
        pathContext.split(pathContext.relative(child.path, from: _outputPath)),
      );
      if (!relativePath.endsWith('.html') ||
          _expectedFiles.contains(relativePath)) {
        continue;
      }

      try {
        final file = child as File;
        if (isLegacyGuideRedirectHtml(file.readAsStringSync())) {
          file.delete();
          _deletedCount++;
        }
      } on FileSystemException {
        // If we can't read or delete the file, skip it silently.
      }
    }
  }

  /// Recursively scans [dirRelative] under [_outputPath] and deletes files
  /// with [extension] that are NOT in [_expectedFiles].
  ///
  /// When [skipRootFiles] is `true`, only files in subdirectories are
  /// considered for deletion — files directly in [dirRelative] are preserved.
  /// This protects scaffold and user-created files (e.g., `guide/index.md`).
  ///
  /// Uses a [visited] set to protect against symlink loops, matching the
  /// shared guide collection traversal logic.
  /// Normalizes paths to POSIX separators for cross-platform consistency.
  void _deleteStaleInDir(
    String dirRelative,
    String extension, [
    Set<String>? visited,
    bool skipRootFiles = false,
  ]) {
    visited ??= {};
    final pathContext = resourceProvider.pathContext;
    final dirPath = pathContext.normalize(
      pathContext.join(_outputPath, dirRelative),
    );
    if (!visited.add(dirPath)) return; // Symlink loop protection.
    final folder = resourceProvider.getFolder(dirPath);
    if (!folder.exists) return;

    final isRoot = visited.length == 1;
    for (final child in folder.getChildren()) {
      if (child is Folder) {
        // Recurse into subdirectories (skipRootFiles only applies to root).
        final relativePath = pathContext.relative(
          child.path,
          from: _outputPath,
        );
        _deleteStaleInDir(relativePath, extension, visited);
      } else {
        // Skip files directly in the root directory when requested.
        if (skipRootFiles && isRoot) continue;

        // Normalize to POSIX separators so the path matches _expectedFiles
        // (which always uses forward slashes).
        final relativePath = p.posix.joinAll(
          pathContext.split(
            pathContext.relative(child.path, from: _outputPath),
          ),
        );
        if (relativePath.endsWith(extension) &&
            !_expectedFiles.contains(relativePath)) {
          try {
            (child as File).delete();
            _deletedCount++;
          } on FileSystemException {
            // If we can't delete the file, skip it silently.
          }
        }
      }
    }

    // Remove empty subdirectories left after stale file deletion.
    // Re-read children because files may have been deleted above.
    if (!folder.exists) return;
    for (final child in folder.getChildren()) {
      if (child is Folder) {
        try {
          if (child.getChildren().isEmpty) {
            child.delete();
          }
        } on FileSystemException {
          // If we can't inspect or delete the directory, skip it silently.
        }
      }
    }
  }

  /// Logs a summary of generation statistics.
  void _logSummary() {
    logInfo(
      'Generated: $_writtenCount written, '
      '$_unchangedCount unchanged, '
      '$_deletedCount deleted',
    );
  }

  // ---------------------------------------------------------------------------
  // Accessors for generation statistics
  // ---------------------------------------------------------------------------

  /// All file paths written during this generation run.
  Set<String> get expectedFiles => Set.unmodifiable(_expectedFiles);

  /// Number of files that were written (new or changed content).
  int get writtenCount => _writtenCount;

  /// Number of files skipped because content was identical.
  int get unchangedCount => _unchangedCount;

  /// Number of stale files deleted during cleanup.
  int get deletedCount => _deletedCount;
}

class _ApiSymbolEntry {
  const _ApiSymbolEntry({
    required this.href,
    required this.relativePath,
    required this.apiDir,
  });

  final String href;
  final String relativePath;
  final String apiDir;
}

// ---------------------------------------------------------------------------
// _NoOpTemplates
// ---------------------------------------------------------------------------

/// A no-op [Templates] implementation that satisfies [GeneratorBackend]'s
/// constructor requirement.
///
/// [JasprGeneratorBackend] never calls any template rendering methods
/// because it overrides all `generate*()` methods and never delegates to
/// `super`. All template methods return an empty string.
class _NoOpTemplates implements Templates {
  @override
  String renderCategory(CategoryTemplateData context) => '';

  @override
  String renderCategoryRedirect(CategoryTemplateData context) => '';

  @override
  String renderClass<T extends Class>(ClassTemplateData context) => '';

  @override
  String renderConstructor(ConstructorTemplateData context) => '';

  @override
  String renderEnum(EnumTemplateData context) => '';

  @override
  String renderError(PackageTemplateData context) => '';

  @override
  String renderExtension(ExtensionTemplateData context) => '';

  @override
  String renderExtensionType(ExtensionTypeTemplateData context) => '';

  @override
  String renderFunction(FunctionTemplateData context) => '';

  @override
  String renderIndex(PackageTemplateData context) => '';

  @override
  String renderLibrary(LibraryTemplateData context) => '';

  @override
  String renderLibraryRedirect(LibraryTemplateData context) => '';

  @override
  String renderMethod(MethodTemplateData context) => '';

  @override
  String renderMixin(MixinTemplateData context) => '';

  @override
  String renderProperty(PropertyTemplateData context) => '';

  @override
  String renderSearchPage(PackageTemplateData context) => '';

  @override
  String renderSidebarForContainer(
    TemplateDataWithContainer<Documentable> context,
  ) => '';

  @override
  String renderSidebarForLibrary(
    TemplateDataWithLibrary<Documentable> context,
  ) => '';

  @override
  String renderTopLevelProperty(TopLevelPropertyTemplateData context) => '';

  @override
  String renderTypedef(TypedefTemplateData context) => '';
}
