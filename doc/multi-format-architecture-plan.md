---
internal: true
---

# Multi-Format Architecture Plan

Status: implemented through Phase 5

Target:
- add `--format jaspr` alongside `html` and `vitepress`
- keep VitePress stable during refactor
- prepare for future non-analyzer input, but do not overdesign for it now

## Executive Summary

The current codebase already has one useful format boundary: `GeneratorBackend`.
That is the right place to extend first.

The wrong first move is to introduce 5-7 new ports before a second working
backend exists. Right now too much VitePress-specific behavior is embedded in:

- `lib/src/generator/vitepress_renderer.dart`
- `lib/src/generator/vitepress_doc_processor.dart`
- `lib/src/generator/vitepress_paths.dart`
- `lib/src/generator/vitepress_sidebar_generator.dart`
- `lib/src/generator/vitepress_init.dart`
- `lib/resources/vitepress/`

So the recommended path is:

1. remove current format leaks from orchestration
2. add lifecycle hooks to `GeneratorBackend`
3. build a minimal Jaspr backend that really works
4. only then extract shared code proven by duplication

This minimizes risk and keeps VitePress behavior stable while making the
architecture actually extensible.

## Top 3 Architecture Variants

### Option 1: Incremental backend refactor, no large port layer upfront

Description:
- keep `GeneratorBackend` as the primary format boundary
- add a few explicit lifecycle hooks
- extract only proven shared primitives after Jaspr duplication appears

Scores:
- confidence: 9/10
- reliability: 9/10
- delivery speed: 8/10
- extensibility: 8/10

Why this is recommended:
- smallest diff for Phase 1-3
- easiest to verify with existing VitePress tests
- avoids inventing abstractions before we know Jaspr constraints

### Option 2: Light port/adapter after spike

Description:
- keep `GeneratorBackend`
- add 2-3 secondary interfaces only after a Jaspr spike proves the need
- likely candidates: path/doc/guide collection

Scores:
- confidence: 7/10
- reliability: 8/10
- delivery speed: 6/10
- extensibility: 9/10

When to choose:
- after Jaspr alpha exists
- after duplicate code is visible in both format backends

### Option 3: Full port/adapter with 5 ports immediately

Description:
- create `PathResolver`, `DocProcessor`, `SidebarGenerator`,
  `GuideGenerator`, `ScaffoldGenerator` before a second backend ships

Scores:
- confidence: 5/10
- reliability: 6/10
- delivery speed: 3/10
- extensibility: 8/10

Why this is not recommended now:
- too much speculative abstraction
- large diff before any user-facing gain
- high chance of moving VitePress-specific assumptions into fake "core"

## Current Reality In The Codebase

### What already works as a format boundary

`GeneratorBackend` is already the real top-level extension point.

Current flow:

```text
Dart source
  -> analyzer
  -> PackageBuilder
  -> PackageGraph / ModelElement / ElementType
  -> Generator
  -> GeneratorBackend
  -> output files
```

Current format selection:

```dart
// lib/src/dartdoc.dart
final generator = format == 'vitepress'
    ? initVitePressGenerator(context, writer: writer)
    : initHtmlGenerator(context, writer: writer);

return Dartdoc._(
  context,
  outputDir,
  generator,
  packageBuilder,
);
```

This means adding a third backend is straightforward structurally.

### Where the architecture currently leaks

#### 1. Traversal knows about VitePress

`Generator._generateDocs()` contains a backend type check to skip duplicate SDK
libraries only for VitePress. That logic belongs to the backend, not to the
shared traversal.

Current anti-pattern:

```dart
if (_generatorBackend is VitePressGeneratorBackend &&
    (isDuplicateSdkLibrary(lib, allPackageLibs) ||
        isInternalSdkLibrary(lib))) {
  continue;
}
```

This must be replaced by a hook on the backend.

#### 2. `generateSearchIndex()` is used as a hidden finalizer

VitePress overrides `generateSearchIndex()` to delete stale files and log a
summary instead of generating search data.

Current anti-pattern:

```dart
@override
void generateSearchIndex(List<Documentable> indexedElements) {
  _deleteStaleFiles();
  _logSummary();
}
```

That is semantically confusing and will get worse with Jaspr.

#### 3. Renderer is deeply VitePress-specific

The current renderer does not just render neutral markdown. It emits:

- VitePress `<Badge />` components
- `outlineCollapsible` frontmatter
- VitePress-specific CSS class names
- raw HTML links styled for VitePress
- assumptions about VitePress markdown processing

Examples:

```dart
buf.write('<Badge type="warning" text="deprecated" /> ');
```

```dart
_buffer.writeln('outlineCollapsible: true');
```

```dart
'<a href="$url" class="type-link">$name</a>'
```

So "80 percent of markdown is shared" is not a safe planning assumption yet.

#### 4. Scaffold and UX features are frontend-specific

Many important features live in `lib/resources/vitepress/`, not in pure Dart
generation:

- breadcrumb component
- DartPad component
- API auto-linker plugin
- outline collapse composable
- mermaid zoom integration

Jaspr support therefore requires both:

- backend output generation
- frontend runtime/scaffold work

#### 5. Future JSON input is not a simple input-layer swap

Current VitePress output code depends directly on:

- `PackageGraph`
- `Documentable`
- `ModelElement`
- `Library`
- `ElementType`
- `referenceBy()`
- `canonicalLibrary`

That means a future non-analyzer input must either:

1. adapt into a PackageGraph-compatible model
2. or introduce a new internal doc domain model and migrate output to it

Replacing only `PackageBuilder` is not enough.

## Architecture Decision

### Recommended Direction

Use `GeneratorBackend` as the stable top-level port.

Add explicit lifecycle hooks for format-specific orchestration.

Extract only format-neutral primitives after Jaspr alpha proves duplication.

### Recommended Target Shape

```text
lib/src/generator/
  generator.dart
  generator_backend.dart
  template_data.dart

  core/
    path_utils.dart
    html_sanitizer.dart
    guide_collection.dart
    render_primitives.dart

  vitepress/
    backend.dart
    renderer.dart
    paths.dart
    docs.dart
    sidebar.dart
    scaffold.dart

  jaspr/
    backend.dart
    renderer.dart
    paths.dart
    docs.dart
    sidebar.dart
    scaffold.dart
```

Important rule:
- `core/` must not emit VitePress-only or Jaspr-only syntax

## Explicit Non-Goals

These should not be attempted in the first refactor:

- introducing a full DI container
- introducing 5+ ports before Jaspr alpha exists
- rewriting `Generator._generateDocs()`
- introducing an internal `DocGraph` before there is a real JSON source
- claiming full VitePress/Jaspr parity before scaffold/runtime spikes pass

## Phase Plan

### Phase 0: Feasibility Spike

Goal:
- validate the risky assumptions before architecture extraction

Required checks:

1. Can Jaspr render the same generated markdown pages cleanly?
2. Can inline API autolinking be implemented at markdown parse/render time?
3. Can DartPad embeds be represented without ugly fallback HTML?
4. Can outline collapse behavior be reproduced?
5. Can search handle a large docs set, ideally the SDK-sized site?
6. Can mermaid be integrated with acceptable UX?
7. Is there a practical replacement for VitePress `<<<` code import?
8. Can a real Jaspr scaffold app consume generated content without ad-hoc hacks?

Deliverables:
- small Jaspr prototype app in a scratch branch or temporary folder
- one real scaffold smoke test:
  - create a minimal Jaspr app
  - copy a small subset of generated markdown into it
  - wire basic routing/sidebar/content loading
  - verify actual rendering in browser, not just unit-level parsing
- written notes on each capability
- clear status per feature: yes / partial / no / unknown

Recommended output table:

| Capability | Result | Confidence | Notes |
|-----------|--------|------------|-------|
| Markdown rendering | yes/partial/no | x/10 | |
| Search at scale | yes/partial/no | x/10 | |
| DartPad embed | yes/partial/no | x/10 | |
| API auto-linker | yes/partial/no | x/10 | |
| Outline collapse | yes/partial/no | x/10 | |
| Mermaid | yes/partial/no | x/10 | |
| Code import | yes/partial/no | x/10 | |
| Real scaffold smoke test | yes/partial/no | x/10 | |

DoD:
- no architecture extraction starts until this table exists

### Phase 1: Clean Up Generator Lifecycle

Goal:
- move format-specific orchestration decisions out of shared traversal

#### Changes

##### 1. Extend supported formats

Update `lib/src/dartdoc_options.dart`:

```dart
DartdocOptionArgFile<String>(
  'format',
  'html',
  resourceProvider,
  help: 'Output format: html, vitepress, or jaspr.',
),
```

Update `lib/src/dartdoc.dart`:

```dart
if (format != 'html' && format != 'vitepress' && format != 'jaspr') {
  throw DartdocOptionError(
    "Invalid format '$format'. Allowed values: html, vitepress, jaspr.",
  );
}
```

Update generator selection:

```dart
final generator = switch (format) {
  'vitepress' => initVitePressGenerator(context, writer: writer),
  'jaspr' => initJasprGenerator(context, writer: writer),
  _ => initHtmlGenerator(context, writer: writer),
};
```

##### 2. Add backend lifecycle hooks

Add hooks to `GeneratorBackend`:

```dart
import 'dart:async';

abstract class GeneratorBackend {
  ...

  Future<void> generateAdditionalFiles();

  FutureOr<void> beforeGenerate(PackageGraph packageGraph) {}

  bool shouldSkipLibrary(
    PackageGraph packageGraph,
    Package package,
    Library library,
    Iterable<Library> allPackageLibraries,
  ) {
    return false;
  }

  FutureOr<void> afterGenerate(
    PackageGraph packageGraph,
    List<Documentable> indexedElements,
    List<ModelElement> categorizedElements,
  ) {
    generateCategoryJson(categorizedElements);
    generateSearchIndex(indexedElements);
  }
}
```

##### 3. Use those hooks in `Generator`

Refactor `Generator.generate()`:

```dart
Future<void> generate(PackageGraph? packageGraph) async {
  await _generatorBackend.generateAdditionalFiles();

  if (packageGraph == null) return;

  await _generatorBackend.beforeGenerate(packageGraph);

  final indexElements = _generateDocs(packageGraph);
  final categorizedElements = indexElements
      .whereType<ModelElement>()
      .where((e) => e.hasCategorization)
      .toList(growable: false);

  await _generatorBackend.afterGenerate(
    packageGraph,
    indexElements,
    categorizedElements,
  );
}
```

Refactor library skip in `_generateDocs()`:

```dart
for (final lib in package.libraries.whereDocumented) {
  if (_generatorBackend.shouldSkipLibrary(
    packageGraph,
    package,
    lib,
    allPackageLibs,
  )) {
    continue;
  }

  _generatorBackend.generateLibrary(packageGraph, lib);
  ...
}
```

##### 4. Move VitePress-specific skip/finalize into backend

In the VitePress backend:

```dart
@override
void beforeGenerate(PackageGraph packageGraph) {
  _paths.initFromPackageGraph(packageGraph);
  _docs = VitePressDocProcessor(
    packageGraph,
    _paths,
    allowedIframeHosts: _allowedIframeHosts,
  );
  _sidebar = VitePressSidebarGenerator(_paths);
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
  _deleteStaleFiles();
  _logSummary();
}
```

Note:
- HTML can keep the default `afterGenerate()` behavior and remain unchanged
- VitePress should move `_paths` / `_docs` / `_sidebar` initialization out of
  `generatePackage()` and into `beforeGenerate()` so backend setup no longer
  depends on traversal order

DoD:
- no backend type checks remain in `Generator`
- VitePress behavior is unchanged
- all current tests pass

Reliability score:
- 9/10

### Phase 2: Extract Only Proven Shared Primitives

Goal:
- extract low-risk shared code without moving format-specific syntax into `core`

#### Good candidates to extract first

##### 1. Path sanitization helpers

Move into `lib/src/generator/core/path_utils.dart`:

```dart
String stripGenerics(String name) { ... }
String sanitizeFileName(String name) { ... }
String sanitizeAnchor(String text) { ... }
```

These are utility-level and not tied to VitePress UI.

##### 2. HTML sanitization primitives

Extract sanitization into something like:

```dart
class HtmlSanitizer {
  static String sanitize(
    String html, {
    Set<String> extraAllowedHosts = const {},
  }) { ... }
}
```

Then VitePress/Jaspr doc processors can reuse it.

Important:
- do not move full reference resolution yet
- only move pure sanitization and preprocess pieces

##### 3. Guide file collection

Split guide generation into:

- neutral collection/parsing
- format-specific sidebar emission

Recommended shape:

```dart
class GuideEntry {
  final String packageName;
  final String relativePath;
  final String title;
  final String content;
  final int? sidebarPosition;
}

class GuideCollector {
  List<GuideEntry> collect(...);
}
```

Keep output formatting separate:

```dart
class VitePressGuideSidebarWriter {
  String generateSidebar(List<GuideEntry> entries, {required bool isMultiPackage});
}

class JasprGuideSidebarWriter {
  String generateSidebarData(List<GuideEntry> entries, {required bool isMultiPackage});
}
```

##### 4. Render primitives, not full page rendering

Acceptable extractions:

- `plainNameWithGenerics()`
- generic escaping helpers
- table-cell escaping
- maybe parameter grouping utilities

Do not extract this yet if it still emits:

- `<Badge />`
- `class="type-link"`
- VitePress frontmatter conventions

#### What must stay format-specific in Phase 2

- page builders
- sidebar generators
- frontend scaffold generators
- all renderer code that emits framework-specific syntax

DoD:
- extracted code has no VitePress-only syntax
- shared code can be used by both future backends without `if (format == ...)`

Reliability score:
- 8/10

### Phase 3: Reorganize Directory Layout

Goal:
- make the codebase legible for multiple output formats

Recommended move:

```text
lib/src/generator/
  core/
    path_utils.dart
    html_sanitizer.dart
    guide_collection.dart
    render_primitives.dart

  vitepress/
    backend.dart
    renderer.dart
    paths.dart
    docs.dart
    sidebar.dart
    scaffold.dart
```

#### Migration strategy

Do not move everything at once.

Safe order:

1. create new files
2. copy code
3. update imports
4. add temporary barrel exports if needed
5. remove old files only after tests pass

Example temporary compatibility export:

```dart
// lib/src/generator/vitepress_paths.dart
export 'package:dartdoc_vitepress/src/generator/vitepress/paths.dart';
```

This reduces churn while the refactor is in flight.

DoD:
- VitePress code lives under `generator/vitepress/`
- temporary exports preserve compatibility during migration

Reliability score:
- 8/10

### Phase 4: Jaspr Alpha Backend

Goal:
- generate correct API markdown/pages and a buildable Jaspr scaffold
- do not promise UX parity yet

#### Definition of Jaspr Alpha

Jaspr Alpha means:

- `--format jaspr` is accepted
- docs generate successfully
- internal cross-links work
- scaffold app builds
- generated markdown is readable in Jaspr
- basic sidebar/navigation exists

It does not yet mean:

- full feature parity with VitePress
- optimized search
- polished interactive features

#### Recommended file set

```text
lib/src/generator/jaspr/
  backend.dart
  renderer.dart
  paths.dart
  docs.dart
  sidebar.dart
  scaffold.dart

lib/resources/jaspr/
  pubspec.yaml
  lib/main.dart
  lib/app.dart
  lib/content/
  lib/components/
  lib/generated/
```

#### Minimal backend composition

```dart
class JasprGeneratorBackend extends GeneratorBackend {
  final JasprPathResolver _paths;
  late JasprDocProcessor _docs;
  late JasprSidebarGenerator _sidebar;
  ...

  @override
  void beforeGenerate(PackageGraph packageGraph) {
    _paths.initFromPackageGraph(packageGraph);
    _docs = JasprDocProcessor(packageGraph, _paths,
      allowedIframeHosts: _allowedIframeHosts);
    _sidebar = JasprSidebarGenerator(_paths);
  }

  @override
  void generatePackage(PackageGraph packageGraph, Package package) {
    ...
  }

  @override
  Future<void> generateAdditionalFiles() async {
    final init = JasprInitGenerator(...);
    await init.generate(
      packageName: _packageName,
      repositoryUrl: _repositoryUrl,
    );
  }
}
```

#### Path strategy

Keep API path structure aligned with VitePress as much as possible:

- `/api/`
- `/api/<library>/`
- `/api/<library>/<symbol>`
- `/topics/<category>`
- `/guide/...`

Why:
- simpler mental model
- easier diffing between outputs
- easier future tests

#### Renderer strategy

Start from copying VitePress renderer, then remove or isolate VitePress syntax.

Examples of likely changes:

VitePress-specific:

```dart
'<Badge type="info" text="sealed" />'
```

Jaspr alpha replacement:

```dart
_renderStatusPill('sealed')
```

Where `_renderStatusPill()` initially emits plain HTML or markdown-safe inline
markup supported by Jaspr.

VitePress-specific:

```dart
_buffer.writeln('outlineCollapsible: true');
```

Jaspr alpha:
- omit this frontmatter field entirely
- or emit a Jaspr-specific metadata field if the app reads it

#### Sidebar strategy

Do not force TypeScript-style output into Jaspr.

Emit a generated Dart file that the Jaspr app can consume directly.

Recommended first version:

```dart
const apiSidebarData = <String, dynamic>{
  ...
};
```

Why Dart over JSON:
- easier integration inside the Jaspr app
- simpler evolution toward typed sidebar models
- fewer runtime parsing concerns
- keeps format-specific navigation data inside the Dart toolchain

If typed consumption is desired, prefer a generated model such as:

```dart
class SidebarItemData {
  final String text;
  final String link;
  const SidebarItemData({required this.text, required this.link});
}

const apiSidebarData = <String, List<SidebarItemData>>{
  '/api/': [
    SidebarItemData(text: 'dart:io', link: '/api/dart-io/'),
  ],
};
```

#### Scaffold strategy

Mirror VitePress's `write-if-absent` semantics:

```dart
class JasprInitGenerator {
  Future<void> generate({
    required String packageName,
    String repositoryUrl = '',
  }) async {
    _writeTemplateIfAbsent(...);
    _writeTemplateIfAbsent(...);
    _writeFileToDisk(
      outputFile: 'lib/generated/api_sidebar.dart',
      content: 'const apiSidebarData = <String, dynamic>{};\n',
    );
  }
}
```

DoD:
- `dart run ... --format jaspr --output <dir>` succeeds
- generated Jaspr app builds
- internal symbol links work
- guide pages are copied and readable

Reliability score:
- 7/10

### Phase 5: Jaspr UX Parity

Goal:
- close the user-facing feature gap after alpha is stable

#### Feature matrix

##### 1. Search

Required:
- verify on a large doc set, ideally the SDK site

Do not accept "search exists" as enough.

Check:
- indexing time
- client load time
- result quality
- memory footprint
- mobile usability

Acceptance score:
- relevance: 8/10 minimum
- performance: 7/10 minimum

##### 2. DartPad embeds

Two implementation directions:

Option A:
- preserve a markdown syntax like fenced `dartpad`
- convert into Jaspr component nodes

Option B:
- preserve raw placeholder HTML that Jaspr replaces at runtime

Preferred direction:
- component-based, because it is easier to validate and maintain

Example generated markup:

```html
<dart-pad
  data-mode="dart"
  data-run="true"
  data-height="400"
  data-source-base64="...">
</dart-pad>
```

Then Jaspr hydrates it into a component.

##### 3. API auto-linker

Do not hardcode this only inside frontend JS.

Prefer one of:

- markdown extension phase
- server-side transformation during generation

Best long-term shape:

```dart
abstract class InlineCodeLinker {
  String process(String markdown, LinkContext context);
}
```

But only introduce this if both backends need it.

##### 4. Outline collapse

Treat this as a UI concern, not generator-core concern.

The generator should only expose metadata such as:

```yaml
outlineCollapsible: true
```

or Jaspr equivalent:

```json
{
  "outlineCollapsible": true
}
```

The actual collapse behavior belongs in the frontend app.

##### 5. Breadcrumbs

Do not rebuild breadcrumb logic separately in multiple places.

Recommended:
- generator emits enough page metadata
- frontend computes breadcrumb UI from that metadata

Example generated metadata:

```yaml
library: "dart:io"
category: "I/O"
container: "File"
kind: "class"
```

##### 6. Mermaid

Treat this as scaffold integration, not backend logic.

The backend should just preserve mermaid markdown fences if possible.

Only add custom generator preprocessing if Jaspr cannot render them directly.

##### 7. Code import

This is one of the highest-risk features because it is usually a docs-engine
concern, not an API-generator concern.

Recommended fallback order:

1. native Jaspr markdown support if available
2. build-time preprocessor
3. generator-time import expansion

Do not implement this in generator-core unless absolutely necessary.

DoD:
- feature matrix filled with actual pass/fail status
- parity claim is backed by manual verification on non-trivial docs

Reliability score:
- 6/10 initially, can rise after spike results

### Phase 6: Future Pluggable Input Layer

Goal:
- prepare honestly for a future non-analyzer source format

#### Important correction

The following statement is too optimistic and should not be used:

> "If dartdoc ships structured JSON, we replace PackageBuilder and keep output unchanged."

That is only true if the JSON adapter reconstructs all semantics currently
required by output:

- canonical library relationships
- reference resolution
- public/private visibility rules
- type rendering semantics
- categorization
- cross-package relationships

#### Two viable strategies

##### Strategy A: JSON -> PackageGraph-compatible adapter

Description:
- keep existing output stack
- construct a model close enough to current analyzer-backed graph

Scores:
- confidence: 6/10
- reliability: 7/10

Best when:
- upstream JSON is rich
- preserving output logic matters more than internal purity

##### Strategy B: Introduce internal `DocGraph`

Description:
- define a generator-facing intermediate model
- create adapters from analyzer model and future JSON model

Scores:
- confidence: 5/10
- reliability: 8/10

Best when:
- multiple sources are real and active
- analyzer coupling becomes painful

#### Recommendation

Do not build `DocGraph` now.

Instead, document this migration path:

1. ship multi-format output first
2. evaluate real JSON shape when it exists
3. if JSON is shallow, adapt into PackageGraph-like model
4. if JSON is materially different, then introduce `DocGraph`

## Proposed File-by-File Work Plan

### Step 1: format and generator selection

Files:
- `lib/src/dartdoc.dart`
- `lib/src/dartdoc_options.dart`
- `lib/src/generator/generator.dart`

Changes:
- add `jaspr` format option
- add `initJasprGenerator()`
- use `switch` for format selection
- add lifecycle hooks to `GeneratorBackend`

### Step 2: VitePress backend cleanup

Files:
- `lib/src/generator/vitepress_generator_backend.dart`
- `lib/src/generator/generator.dart`

Changes:
- move duplicate SDK skip into backend hook
- move final cleanup/logging into `afterGenerate()`
- stop abusing `generateSearchIndex()` as finalizer

### Step 3: safe shared extraction

Files:
- new `lib/src/generator/core/path_utils.dart`
- new `lib/src/generator/core/html_sanitizer.dart`
- new `lib/src/generator/core/guide_collection.dart`
- later optional `lib/src/generator/core/render_primitives.dart`

Changes:
- move only neutral functions
- keep format emitters local

### Step 4: move VitePress into subdirectory

Files:
- move current VitePress generator files under `lib/src/generator/vitepress/`
- leave temporary export shims if needed

### Step 5: Jaspr alpha

Files:
- new `lib/src/generator/jaspr/*`
- new `lib/resources/jaspr/*`
- new end-to-end tests

### Step 6: parity work

Files:
- mostly `lib/resources/jaspr/*`
- only targeted generator changes as required

## Testing Plan

### Automated

Run after every phase:

```bash
dart analyze --fatal-infos
dart test
```

Minimum targeted checks during migration:

```bash
dart test test/end2end/vitepress_generator_test.dart
dart test test/vitepress_paths_test.dart
dart test test/vitepress_doc_processor_test.dart
dart test test/vitepress_guide_generator_test.dart
```

Add new tests as extraction happens:

```text
test/generator/core/path_utils_test.dart
test/generator/core/html_sanitizer_test.dart
test/generator/core/guide_collection_test.dart
test/end2end/jaspr_generator_test.dart
```

### Manual

VitePress generation:

```bash
dart run /Users/belief/dev/projects/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  --format vitepress \
  --output /tmp/test-vitepress
```

Jaspr generation:

```bash
dart run /Users/belief/dev/projects/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  --format jaspr \
  --output /tmp/test-jaspr
```

SDK-scale verification:

```bash
cd /tmp/dart-sdk-vitepress && \
dart run /Users/belief/dev/projects/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  --sdk-docs --format vitepress --output docs-site
```

Future Jaspr equivalent should be added once scaffold exists.

Implemented Jaspr verification:

```bash
tmpdir=$(mktemp -d /tmp/dart-sdk-jaspr.XXXXXX) && \
dart run /Users/belief/dev/projects/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  --sdk-docs --format jaspr --output "$tmpdir"

dart run tool/jaspr_search_benchmark.dart \
  "$tmpdir/lib/generated/search_index.json" \
  Future Stream Uri File
```

Latest verification notes are recorded in:

```text
doc/jaspr-search-verification.md
```

## Risk Register

### Risk 1: fake shared core

Symptom:
- `core/` starts containing VitePress badges, CSS classes, or frontmatter

Severity:
- 9/10

Mitigation:
- only extract code that can compile and make sense without either frontend

### Risk 2: hidden lifecycle coupling

Symptom:
- backend cleanup/search/finalization stays implicit

Severity:
- 8/10

Mitigation:
- add explicit hooks in `GeneratorBackend`

### Risk 3: Jaspr parity assumptions are wrong

Symptom:
- search, code import, or markdown extension support is weaker than expected

Severity:
- 9/10

Mitigation:
- Phase 0 spike before architecture extraction

### Risk 4: source-input preparation is overbuilt

Symptom:
- large internal model rewrite before there is a real second input source

Severity:
- 7/10

Mitigation:
- defer `DocGraph` until a real JSON producer exists

## Acceptance Criteria For The Whole Project

The initiative is complete only when:

1. `vitepress` output remains stable
2. `jaspr` output is a real supported format, not a partial demo
3. generator lifecycle has no format-specific hacks in shared traversal
4. shared code is truly format-neutral
5. future non-analyzer input path is documented honestly, without false claims

## Final Recommendation

Build this in the following order:

1. Phase 0 feasibility spike
2. Phase 1 lifecycle cleanup
3. Phase 2 selective shared extraction
4. Phase 3 directory reorganization
5. Phase 4 Jaspr alpha
6. Phase 5 parity work
7. Phase 6 future input abstraction only when justified

This order has the best tradeoff:

- confidence: 9/10
- reliability: 9/10
- delivery speed: 7/10
- future flexibility: 8/10

It is the safest way to get a real second backend without destabilizing the
current VitePress generator.
