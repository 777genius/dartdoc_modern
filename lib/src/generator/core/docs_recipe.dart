import 'package:analyzer/file_system/file_system.dart';
import 'package:path/path.dart' as p;

const selfDocsRecipeName = 'self-docs';
const supportedDocsRecipes = {selfDocsRecipeName};

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

  final displayName = packageName.replaceAll('_', '-');
  final gitHubLink = repositoryUrl.isNotEmpty
      ? ' | [GitHub]($repositoryUrl)'
      : '';

  return '''---
title: "$displayName"
description: "Modern API docs for Dart"
outline: false
---

# $displayName

Drop-in replacement for `dart doc` that generates a modern docs site with VitePress or Jaspr.

[Guide](/guide) | [API Reference](/api)$gitHubLink

## Highlights

- Fast local search for guides and API pages
- Guide pages next to analyzer-driven API docs
- VitePress and Jaspr backends from one generator
- DartPad embeds, Mermaid, breadcrumbs, and theming
- Workspace docs support for larger Dart repos

## Install

```bash
dart pub global activate dartdoc_vitepress
```

## Quick Start

```bash
# VitePress output
dartdoc_vitepress --format vitepress --output docs-site

# Jaspr output
dartdoc_vitepress --format jaspr --output docs-site
```

## Compare Backends

| Backend | Best fit |
|---|---|
| `vitepress` | strongest static-site ecosystem and lowest-risk polished path |
| `jaspr` | Dart-first docs app scaffold with typed generated navigation |
| `html` | compatibility with the original dartdoc output |

## Live Example

[Dart SDK API docs](https://777genius.github.io/dart-sdk-api/) generated with `dartdoc-vitepress`.
''';
}
