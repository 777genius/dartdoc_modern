import 'package:analyzer/file_system/file_system.dart';
import 'package:path/path.dart' as p;

const selfDocsRecipeName = 'self-docs';
const supportedDocsRecipes = {selfDocsRecipeName};
const projectSiteBaseUrl = 'https://777genius.github.io/dartdoc_modern';
const projectVitePressSiteUrl = '$projectSiteBaseUrl/vitepress/';
const projectJasprSiteUrl = '$projectSiteBaseUrl/jaspr/';

bool isSelfDocsRecipe(String? recipe) => recipe == selfDocsRecipeName;

String? validateDocsRecipe(String? recipe) {
  if (recipe == null || supportedDocsRecipes.contains(recipe)) {
    return null;
  }
  final supported = supportedDocsRecipes.toList()..sort();
  return 'Unsupported docs recipe "$recipe". '
      'Supported values: ${supported.join(', ')}.';
}

List<String> resolveGuideDirsForRecipe(
  String? recipe, {
  required List<String> fallback,
}) {
  if (!isSelfDocsRecipe(recipe)) {
    return fallback;
  }
  return const ['doc', 'docs-site/guide'];
}

List<String> resolveGuideExcludeForRecipe(
  String? recipe, {
  required List<String> fallback,
}) {
  if (!isSelfDocsRecipe(recipe)) {
    return fallback;
  }
  return const ['api/static-assets/.*'];
}

Set<String> resolveExcludedLibrariesForRecipe(
  String? recipe, {
  required Set<String> fallback,
  required ResourceProvider resourceProvider,
  required String inputDir,
  required String packageName,
}) {
  if (!isSelfDocsRecipe(recipe)) {
    return fallback;
  }

  final excludes = <String>{
    ...fallback,
    'api_symbols',
    'api_sidebar',
    'guide_sidebar',
    'package:$packageName/resources/jaspr/lib/generated/api_sidebar.dart',
    'package:$packageName/resources/jaspr/lib/generated/guide_sidebar.dart',
    'package:$packageName/resources/jaspr/lib/generated/api_symbols.dart',
  };
  final pathContext = resourceProvider.pathContext;
  final packageLibDir = pathContext.normalize(
    pathContext.join(inputDir, 'lib'),
  );
  final scaffoldLibDir = resourceProvider.getFolder(
    pathContext.join(packageLibDir, 'resources', 'jaspr', 'lib'),
  );
  if (!scaffoldLibDir.exists) {
    return excludes;
  }

  void visitFolder(Folder folder) {
    final children = folder.getChildren().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final child in children) {
      if (child is Folder) {
        visitFolder(child);
        continue;
      }
      if (child is! File || !child.path.endsWith('.dart')) {
        continue;
      }

      final relativeToLib = pathContext.relative(
        child.path,
        from: packageLibDir,
      );
      final packageUri = p.posix.joinAll([
        'package:$packageName',
        ...p.posix.split(relativeToLib.replaceAll(pathContext.separator, '/')),
      ]);
      excludes.add(packageUri);
    }
  }

  visitFolder(scaffoldLibDir);
  return excludes;
}

String? buildRecipeHomePageMarkdown(
  String? recipe, {
  required String packageName,
  required String repositoryUrl,
}) {
  if (!isSelfDocsRecipe(recipe)) {
    return null;
  }

  final displayName = packageName;
  final gitHubAction = repositoryUrl.isNotEmpty
      ? '''
    - theme: alt
      text: GitHub
      link: $repositoryUrl
'''
      : '';

  return '''---
layout: home
title: "$displayName"
description: "Modern API docs for Dart"
outline: false
hero:
  name: "$displayName"
  text: Modern API Docs for Dart
  tagline: Drop-in replacement for dart doc — generates a Jaspr or VitePress site with search, dark mode, guides, and full customization
  actions:
    - theme: brand
      text: Quick Start
      link: /guide/
    - theme: alt
      text: API Reference
      link: /api/
$gitHubAction
features:
  - icon: 📚
    title: Full API Reference
    details: Every class, function, and type gets its own page with badges, clickable type links, signatures, and source breadcrumbs.
  - icon: 🔍
    title: Fast Offline Search
    details: Built-in full-text search spans guide pages, API pages, and section headings without any external service.
  - icon: 🌗
    title: Dark Mode & Theme Presets
    details: Light and dark mode ship out of the box, and Jaspr theme presets let you retune the docs shell without rebuilding the app structure.
  - icon: 📖
    title: Guide Pages
    details: Put markdown files in doc/ or docs/ and they become guide routes with sidebar navigation next to the generated API docs.
  - icon: 📦
    title: Workspace Docs
    details: One command can generate a unified docs site for a Dart workspace with package-aware navigation and search.
  - icon: 🎮
    title: Interactive Blocks
    details: DartPad embeds, Mermaid diagrams, badges, callouts, and tabs all survive the generator pipeline.
  - icon: 🔗
    title: Auto-Linking
    details: Write API names in guides and the generator can keep them linkable across the docs site.
  - icon: ⚡
    title: Incremental Generation
    details: The generator only rewrites what changed, so large packages stay workable during iteration.
---

## Install

```bash
dart pub global activate dartdoc_modern
```

## Usage

<Tabs defaultValue="jaspr">
  <TabItem label="Jaspr" value="jaspr">

#### Single package

```bash
dartdoc_modern --format jaspr --output docs-site
cd docs-site && dart pub get && jaspr serve
```

#### Mono-repo

```bash
dartdoc_modern --format jaspr \\
  --workspace-docs \\
  --exclude-packages 'example,test_utils' \\
  --output docs-site
cd docs-site && dart pub get && jaspr serve
```

#### Dart SDK

```bash
dartdoc_modern --sdk-docs --format jaspr --output docs-site
cd docs-site && dart pub get && jaspr serve
```

  </TabItem>
  <TabItem label="VitePress" value="vitepress">

#### Single package

```bash
dartdoc_modern --format vitepress --output docs-site
cd docs-site && npm install && npx vitepress dev
```

#### Mono-repo

```bash
dartdoc_modern --format vitepress \\
  --workspace-docs \\
  --exclude-packages 'example,test_utils' \\
  --output docs-site
```

#### Dart SDK

```bash
dartdoc_modern --sdk-docs --format vitepress --output docs-site
```

  </TabItem>
</Tabs>

## dart doc vs dartdoc_modern

| | dart doc | dartdoc_modern VitePress | dartdoc_modern Jaspr |
|---|---|---|---|
| Output | Static HTML | VitePress (Markdown + Vue) | Jaspr app (Dart + SSR/static build) |
| Search | Basic | Full-text, offline | Full-text, offline |
| Dark mode | No | Yes | Yes |
| Guide docs | No | Auto from `doc/` | Auto from `doc/` |
| Mono-repo | No | `--workspace-docs` | `--workspace-docs` |
| Build speed / file count | Many HTML pages | Much faster, far fewer files | Much faster, far fewer files |
| DartPad embeds | No | Yes | Yes |
| Mermaid diagrams | No | Yes, with zoom | Yes, with runtime rendering |
| Customization | Templates | CSS, Vue components, plugins | Dart components, theme tokens, CSS |

### Why It Builds Much Faster

`dartdoc_modern` is dramatically faster largely because it writes dramatically fewer files.

Standard `dartdoc` creates a separate HTML page for every member. Every method, property, constructor, and constant gets its own full HTML page with head, navigation, sidebar, and footer. `dartdoc_modern` keeps members inline on the library or type page instead.

- The Flutter `Icons` class has about 2,000 static constants. `dartdoc` turns that into about 2,001 pages for one class. `dartdoc_modern` keeps it on one page.
- For the full Dart SDK, `dartdoc` generates roughly 15,000+ HTML files. `dartdoc_modern` generates about 1,800 markdown files, around 52 MB of source markdown.
- For icon packages like `material_design_icons_flutter` with 7,000+ static const icons, `dartdoc` would emit 7,000+ individual pages. `dartdoc_modern` keeps that as one page.

This is a deliberate architectural choice, not a limitation. It reduces file-system churn, cuts I/O, speeds up builds, and makes browsing APIs better: you can `Ctrl+F` through the whole class, jump with the outline, and use search without opening dozens of member pages.

## Live Example

[Dart SDK API docs](https://777genius.github.io/dart-sdk-api/) generated with `dartdoc_modern`.

## Live Versions

- [VitePress version]($projectVitePressSiteUrl)
- [Jaspr version]($projectJasprSiteUrl)
''';
}
