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
  return const ['docs-site/guide'];
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

  final excludes = <String>{...fallback, 'api_symbols'};
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
    - theme: alt
      text: VitePress Version
      link: $projectVitePressSiteUrl
    - theme: alt
      text: Jaspr Version
      link: $projectJasprSiteUrl
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

<Tabs defaultValue="single-package">
  <TabItem label="Single package" value="single-package">

```bash
dartdoc_modern --format vitepress --output docs-site
cd docs-site && npm install && npx vitepress dev
```

  </TabItem>
  <TabItem label="Mono-repo" value="mono-repo">

```bash
dartdoc_modern --format vitepress \\
  --workspace-docs \\
  --exclude-packages 'example,test_utils' \\
  --output docs-site
```

  </TabItem>
  <TabItem label="Jaspr output" value="jaspr-output">

```bash
dartdoc_modern --format jaspr --output docs-site
cd docs-site && dart pub get && jaspr serve
```

  </TabItem>
  <TabItem label="Dart SDK" value="dart-sdk">

```bash
dartdoc_modern --sdk-docs --format vitepress --output docs-site
```

  </TabItem>
</Tabs>

## dart doc vs dartdoc_modern

| | dart doc | dartdoc_modern |
|---|---|---|
| Output | Static HTML | Jaspr or VitePress |
| Search | Basic | Full-text, offline |
| Dark mode | No | Yes |
| Guide docs | No | Auto from `doc/` |
| Mono-repo | No | `--workspace-docs` |
| DartPad embeds | No | Yes |
| Mermaid diagrams | No | Yes, with zoom |
| Customization | Templates | Jaspr theme tokens, CSS, components |

## Live Example

[Dart SDK API docs](https://777genius.github.io/dart-sdk-api/) generated with `dartdoc_modern`.

## Live Versions

- [VitePress version]($projectVitePressSiteUrl)
- [Jaspr version]($projectJasprSiteUrl)
''';
}
