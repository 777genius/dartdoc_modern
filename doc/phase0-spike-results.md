# Phase 0: Feasibility Spike Results

## Test Setup
- jaspr_cli 0.22.4, jaspr_content with DocsLayout
- Template: `--template docs --mode static --routing multi-page`
- Copied dart:core and dart:async API pages from generated VitePress docs
- Built with `jaspr build`, served static output

## Capability Table

| Capability | Result | Confidence | Notes |
|-----------|--------|------------|-------|
| Markdown rendering | yes | 8/10 | Markdown renders correctly. Code blocks, links, headings, lists all work. VitePress-specific anchor syntax `{#id}` renders as raw text - needs stripping. HTML in markdown (div, a, span, pre/code) works. |
| Search at scale | unknown | 4/10 | DocsLayout has search (Cmd+K visible in template). NOT tested at 1800+ pages scale. Need dedicated test with full SDK. |
| DartPad embed | partial | 6/10 | Custom components (`<Info>`, `<Clicker/>`) work in markdown. DartPad would need a new Jaspr component + markdown syntax. Feasible but needs implementation. |
| API auto-linker | partial | 5/10 | jaspr_content uses Dart markdown parser with custom extensions. Can register custom InlineSyntax for auto-linking. Not built-in, needs implementation. |
| Outline collapse | partial | 5/10 | DocsLayout has ToC. Collapse behavior would need custom Jaspr component. Generator can emit metadata, frontend handles collapse. |
| Mermaid | unknown | 4/10 | Not tested. Mermaid fences in markdown would render as code blocks by default. Would need JS interop with mermaid.js or a custom component. |
| Code import | no | 3/10 | No `<<<` equivalent. Would need build-time preprocessor or generator-time expansion. |
| Real scaffold smoke test | yes | 9/10 | `jaspr create --template docs` works. `jaspr build` succeeds. Generated markdown (dart:core, dart:async) renders in browser. Sidebar, dark mode, code highlighting, copy button all present out of the box. |

## Key Findings

### What works out of the box
- Markdown rendering with code highlighting and copy button
- Dark/light mode toggle
- DocsLayout with sidebar navigation
- Custom components in markdown
- HTML elements in markdown (div, a, span, pre/code)
- Static site generation (3MB output for 5 pages)
- Build time: ~20s (fast)

### What needs work for Jaspr adapter
1. **Strip VitePress-specific syntax**: `{#anchor}`, `<Badge />`, `<ApiBreadcrumb />`, `:::info` containers, VitePress frontmatter fields (outline, editLink, prev, next)
2. **Member signatures**: `<pre><code>` blocks render but add spaces around generics `< T >` - may need Jaspr-specific rendering
3. **DartPad component**: needs Jaspr implementation (custom component + markdown extension)
4. **Auto-linker**: needs Jaspr markdown InlineSyntax implementation
5. **Sidebar**: needs Dart-based generation instead of TypeScript
6. **Search at scale**: critical unknown - must test with 1800+ pages before committing

### Blockers
- **Search at scale** is the biggest unknown. If DocsLayout search chokes on 1800+ pages, this is a major issue.
- **Code import** has no native solution - needs custom preprocessor.

## Decision

**Go** for Phase 1 (lifecycle cleanup) - this is VitePress-only work and doesn't depend on Jaspr.

**Conditional go** for Phase 4 (Jaspr alpha) - proceed only after validating search at scale with a larger doc set (~100+ pages minimum).
