// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Documentation processor for VitePress output.
///
/// Takes a [ModelElement]'s `documentation` getter (pre-HTML markdown with
/// bracket references intact), resolves `{@inject-html}` placeholders and
/// cross-references via the markdown parser, and serializes the result back
/// to clean markdown suitable for VitePress rendering.
library;

import 'package:dartdoc_modern/src/comment_references/model_comment_reference.dart';
import 'package:dartdoc_modern/src/generator/core/html_sanitizer.dart'
    as core_sanitize;
import 'package:dartdoc_modern/src/generator/core/path_utils.dart'
    as path_utils;
import 'package:dartdoc_modern/src/generator/core/markdown_paths.dart';
import 'package:dartdoc_modern/src/matching_link_result.dart';
import 'package:dartdoc_modern/src/model/model.dart';
import 'package:dartdoc_modern/src/runtime_stats.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:meta/meta.dart';

part 'markdown_ast_renderer.dart';

/// Regular expression matching `<dartdoc-html>HEXDIGEST</dartdoc-html>`
/// placeholders inserted by the `{@inject-html}` directive processing.
///
/// These placeholders are present in the `documentation` getter and must be
/// resolved BEFORE markdown parsing so the injected HTML passes through
/// the markdown parser as raw HTML content.
final _htmlInjectPattern = RegExp(r'<dartdoc-html>([a-f0-9]+)</dartdoc-html>');

/// Regular expression matching the `htmlBasePlaceholder` that may appear in
/// documentation strings. This is dartdoc's internal placeholder for the
/// HTML base path, which is irrelevant for VitePress output.
final _htmlBasePlaceholder = RegExp(
  r'%%__HTMLBASE_dartdoc_internal__%%',
  multiLine: true,
);

/// Inline syntaxes used for parsing documentation markdown.
///
/// These match the syntaxes used by dartdoc's own `MarkdownDocument`,
/// ensuring consistent parsing behavior.
final List<md.InlineSyntax> _inlineSyntaxes = [
  _InlineCodeSyntax(),
  md.InlineHtmlSyntax(),
  md.StrikethroughSyntax(),
  md.AutolinkExtensionSyntax(),
];

/// Block syntaxes used for parsing documentation markdown.
final List<md.BlockSyntax> _blockSyntaxes = [
  const md.AlertBlockSyntax(),
  const md.FencedCodeBlockSyntax(),
  const md.HeaderWithIdSyntax(),
  const md.SetextHeaderWithIdSyntax(),
  const md.TableSyntax(),
];

/// Returns `false` if [referable] is an unnamed [Constructor], or if it is
/// shadowing another type of element, or is a parameter of one of the above.
///
/// This mirrors the filter logic in `markdown_processor.dart`.
bool _rejectUnnamedAndShadowingConstructors(Referable? referable) {
  if (referable is Constructor) {
    if (referable.isUnnamedConstructor) return false;
    if (referable.enclosingElement.referenceChildren[referable.name
            .split('.')
            .last]
        is! Constructor) {
      return false;
    }
  }
  return true;
}

/// Returns `false` unless [referable] represents a callable object.
bool _requireCallable(Referable? referable) =>
    referable is ModelElement && referable.isCallable;

/// Resolves a bracket reference [referenceText] against [element]'s scope.
///
/// This replicates the logic from `markdown_processor.dart`'s
/// `getMatchingLinkElement()` function without calling the `@visibleForTesting`
/// annotated function directly. Uses the same comment reference parsing and
/// lookup mechanism.
MatchingLinkResult _resolveReference(
  String referenceText,
  ModelElement element,
) {
  var commentReference = ModelCommentReference(referenceText);

  var filter = commentReference.hasCallableHint
      ? _requireCallable
      : _rejectUnnamedAndShadowingConstructors;

  var lookupResult = element.referenceBy(
    commentReference.referenceBy,
    filter: filter,
  );

  var result = MatchingLinkResult(lookupResult);
  runtimeStats.totalReferences++;
  if (result.referable != null) {
    runtimeStats.resolvedReferences++;
  }
  return result;
}

/// Inline syntax for dartdoc's `[: code :]` notation.
///
/// Converts `[: code :]` to markdown inline code (`` `code` ``).
/// This mirrors dartdoc's `_InlineCodeSyntax` from `markdown_processor.dart`,
/// but produces markdown backtick-wrapped code instead of HTML `<code>` elements.
class _InlineCodeSyntax extends md.InlineSyntax {
  _InlineCodeSyntax() : super(r'\[:\s?((?:.|\n)*?)\s?:\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Text('`${match[1]!.trim()}`'));
    return true;
  }
}

/// Processes documentation text from [ModelElement]s for VitePress output.
///
/// The processor performs these steps:
/// 1. Reads the `documentation` getter (pre-HTML markdown with bracket refs)
/// 2. Resolves `{@inject-html}` placeholders via [PackageGraph.getHtmlFragment]
/// 3. Removes `DARTDOC_PARAGRAPH_BREAK` markers (multi-source doc joiners)
/// 4. Parses through the markdown parser with a custom `linkResolver` to
///    resolve `[ClassName]` bracket references into VitePress-compatible links
/// 5. Serializes the resolved AST back to markdown via [MarkdownRenderer]
class MarkdownDocProcessor {
  /// The package graph, used for resolving `{@inject-html}` fragments.
  final PackageGraph packageGraph;

  /// The path resolver, used for computing VitePress URLs for cross-references.
  final MarkdownPathResolver paths;

  /// Additional hostnames whose `<iframe>` elements are preserved by
  /// [sanitizeHtml]. YouTube and DartPad hosts are always allowed.
  final Set<String> allowedIframeHosts;

  MarkdownDocProcessor(
    this.packageGraph,
    this.paths, {
    this.allowedIframeHosts = const {},
  });

  // Pre-compiled pattern for extractOneLineDoc.
  static final _blankLine = RegExp(r'\n\s*\n');

  /// Matches hardcoded relative `.html` links in rendered markdown output.
  ///
  /// These come from SDK source doc comments that contain explicit markdown
  /// links like `[text](dart-developer/foo.html)`. The pattern matches
  /// `[text](relative-path.html)` but NOT `[text](https://...)`.
  static final _hardcodedHtmlLink = RegExp(
    r'\[([^\]]+)\]\((?!https?://)([^)]+\.html)\)',
  );

  /// Matches Flutter platform-embedder paths (`/javadoc/...`,
  /// `/ios-embedder/...`) that should be absolute URLs on api.flutter.dev.
  ///
  /// SDK doc comments reference these paths as relative links, but they are
  /// hosted externally and have no local VitePress equivalent.
  static final _flutterEmbedderLink = RegExp(
    r'\[([^\]]+)\]\((/(javadoc|ios-embedder)/[^)]+)\)',
  );

  /// Processes the full documentation for [element], resolving cross-references
  /// and `{@inject-html}` placeholders.
  ///
  /// Returns clean markdown with:
  /// - All `[ClassName]` bracket references resolved to `[ClassName](url)`
  /// - All `<dartdoc-html>` placeholders replaced with actual HTML content
  /// - HTML from `{@youtube}`, `{@animation}` directives passed through
  String processDocumentation(ModelElement element) {
    var text = element.documentation;
    if (text.isEmpty) return '';

    text = _preprocess(text);
    return _resolveReferences(text, element);
  }

  /// Extracts the first paragraph from documentation as a one-line description.
  ///
  /// Used for library overview tables where only a brief description is needed.
  /// Processes the full documentation through [processDocumentation] first to
  /// resolve `[ClassName]` bracket references into proper markdown links, then
  /// extracts the first paragraph and collapses it to a single line.
  ///
  /// If the documentation is empty, returns an empty string.
  String extractOneLineDoc(ModelElement element) {
    final doc = element.documentation;
    if (doc.isEmpty) return '';

    // Process through the full pipeline to resolve bracket references.
    final processed = processDocumentation(element);
    if (processed.isEmpty) return '';

    // Take the first paragraph (up to the first blank line or end of text).
    final firstPara = processed.split(_blankLine).first.trim();

    // Collapse to a single line by replacing newlines with spaces.
    return firstPara.replaceAll('\n', ' ');
  }

  /// Processes raw documentation text that is not attached to a [ModelElement].
  ///
  /// Runs pre-processing (inject-html resolution, placeholder stripping) and
  /// converts hardcoded `.html` links to VitePress paths, but does NOT resolve
  /// bracket references since there is no element context.
  /// Used for [Category] docs, package docs, and other non-ModelElement
  /// documentation.
  String processRawDocumentation(String? text) {
    if (text == null || text.isEmpty) return '';
    var result = _preprocess(text);
    // Rewrite hardcoded relative .html links (same as in _resolveReferences).
    result = result.replaceAllMapped(_hardcodedHtmlLink, (m) {
      final linkText = m[1]!;
      final path = _convertHtmlPathToVitePress(m[2]!);
      // Empty path means the target has no generated page (e.g. private
      // SDK libraries like dart._http). Render as inline code.
      if (path.isEmpty) return '`$linkText`';
      return '[$linkText]($path)';
    });
    // Run through the markdown parser + renderer to escape angle brackets
    // in non-code contexts. Without this, raw documentation text containing
    // generic type parameters (e.g. `List<E>` in package READMEs or category
    // docs) would cause VitePress/Vue template compilation errors.
    final document = md.Document(
      blockSyntaxes: _blockSyntaxes,
      inlineSyntaxes: _inlineSyntaxes,
      encodeHtml: false,
    );
    final nodes = document.parse(result);
    result = MarkdownRenderer().render(nodes);
    return sanitizeHtml(result, extraAllowedHosts: allowedIframeHosts);
  }

  /// Converts a dartdoc-style relative `.html` path to a VitePress path.
  ///
  /// Handles:
  /// - Stripping leading `../` segments
  /// - Removing `.html` extension
  /// - Converting `-library` suffix to `/` (library index pages)
  /// - Deduplicating `dir/dir` paths (e.g. `dart-async/dart-async` -> `dart-async/`)
  /// - Normalizing internal SDK library directory names (`dart.io` -> `dart-io`,
  ///   `dart.dom.html` -> `dart-html`)
  /// - Adding `/api/` prefix
  /// - Normalizing the path via [Uri] to resolve any remaining `..` segments
  static String _convertHtmlPathToVitePress(String rawPath) {
    var path = rawPath;
    // Strip leading `../` segments (relative paths from nested doc comments).
    path = path.replaceFirst(RegExp(r'^(\.\./)+'), '');
    // Remove .html extension.
    path = path.replaceFirst(RegExp(r'\.html$'), '');
    // Handle library index pages: dart-core-library -> dart-core/
    path = path.replaceFirst(RegExp(r'-library$'), '/');
    // Deduplicate dir/dir pattern: when the last segment matches the parent
    // directory name, collapse to just the directory with trailing slash.
    // E.g. `dart-async/dart-async` -> `dart-async/`
    //       `dart-async/dart-async/` -> `dart-async/`
    final dedup = RegExp(r'([^/]+)/\1/?$');
    path = path.replaceFirstMapped(dedup, (m) => '${m[1]}/');
    // Handle ClassName/memberName pattern: when the path has exactly two
    // segments and the first is NOT a known SDK library directory (dart-*),
    // treat the second segment as an anchor (member name on the class page).
    // E.g. `SubForDocComments/localMethod` -> `SubForDocComments#localmethod`
    final segments = path.split('/');
    if (segments.length == 2 &&
        segments[1].isNotEmpty &&
        !segments[0].startsWith('dart-') &&
        !segments[0].startsWith('dart.') &&
        !segments[0].contains('-library')) {
      path = '${segments[0]}#${segments[1].toLowerCase()}';
    }
    // Normalize internal SDK library directory names in the path.
    // The Dart SDK creates duplicate Library objects with internal names
    // like `dart.io` (dirName `dart.io`) alongside canonical `dart:io`
    // (dirName `dart-io`). Doc comment hrefs use the internal dirName,
    // producing paths like `dart.io/SomeClass` that don't exist in the
    // generated output. Rewrite these to the canonical form.
    // Returns empty string for private SDK libraries (dart._http, etc.)
    // which have no generated pages.
    path = normalizeSdkLibraryPath(path);
    if (path.isEmpty) return '';
    // Make absolute with /api/ prefix.
    if (!path.startsWith('/')) {
      path = '/api/$path';
    }
    // Normalize the path to resolve any remaining relative segments.
    // Uri.parse strips the fragment (#anchor) from .path, so we need
    // to preserve it and re-append after normalization.
    final uri = Uri.parse(path);
    var normalized = uri.normalizePath().path;
    if (uri.hasFragment) {
      normalized = '$normalized#${uri.fragment}';
    }
    return normalized;
  }

  /// Matches internal SDK library directory names (`dart.xxx`) at the
  /// beginning of a path segment.
  ///
  /// Captures:
  /// - Group 1: the internal library dirName (e.g. `dart.io`, `dart.dom.html`,
  ///   `dart._http`)
  /// - The rest of the path follows after a `/` or end of string.
  /// Normalizes internal SDK library directory names in a path.
  ///
  /// Rewrites the first path segment when it matches `dart.xxx`:
  /// - `dart.dom.xxx/...` -> `dart-xxx/...` (strip `.dom.` prefix)
  /// - `dart._xxx/...` -> returns empty string (private SDK libraries have no
  ///   generated pages; the caller should render as inline code)
  /// - `dart.xxx/...` -> `dart-xxx/...` (replace first `.` with `-`)
  @visibleForTesting
  static String normalizeSdkLibraryPath(String path) =>
      path_utils.normalizeSdkLibraryPath(path);

  /// Non-HTML marker for `{@inject-html}` placeholders.
  ///
  /// The original `<dartdoc-html>HEXDIGEST</dartdoc-html>` markers are replaced
  /// with `DARTDOC_INJECT{HEXDIGEST}` before the markdown parser, so the parser
  /// treats them as plain text (not HTML). After rendering, the markers are
  /// resolved to actual HTML content.
  static final _injectMarker = RegExp(r'DARTDOC_INJECT\{([a-f0-9]+)\}');

  /// Pattern matching raw `{@inject-html}...{@end-inject-html}` directives
  /// that were not processed into `<dartdoc-html>` placeholders (because
  /// the `--inject-html` flag was not enabled). The HTML content between the
  /// tags is preserved; only the directive markers are stripped.
  static final _rawInjectHtmlDirective = RegExp(
    r'\{@inject-html\s*\}(.*?)\{@end-inject-html\}',
    dotAll: true,
  );

  /// Pattern matching `{@tool ...}...{@end-tool}` directive blocks.
  ///
  /// These are Flutter-specific directives that produce interactive samples.
  /// When the tool infrastructure is not available (e.g. non-Flutter packages),
  /// these directives pass through unresolved. We strip them to avoid raw
  /// directive text in the output.
  static final _toolDirective = RegExp(
    r'[ ]*\{@tool\s+[^\}]*\}\n?[\s\S]*?\n?\{@end-tool\}[ ]*\n?',
  );

  /// Pre-processes raw documentation text before markdown parsing.
  ///
  /// Performs four transformations in order:
  /// 1. Replaces `<dartdoc-html>` placeholders with non-HTML markers
  /// 2. Strips `htmlBasePlaceholder` strings (irrelevant for VitePress)
  /// 3. Removes `DARTDOC_PARAGRAPH_BREAK` markers (multi-source doc joiners)
  /// 4. Strips unresolved `{@tool}` directives (Flutter-specific)

  String _preprocess(String text) {
    // Step 1: Replace {@inject-html} placeholders with non-HTML markers.
    // The `documentation` getter contains `<dartdoc-html>HEXDIGEST</dartdoc-html>`
    // placeholders. We convert them to `DARTDOC_INJECT{HEXDIGEST}` so the
    // markdown parser doesn't treat them as HTML. After rendering, we resolve
    // these markers back to actual HTML content.
    text = text.replaceAllMapped(
      _htmlInjectPattern,
      (m) => 'DARTDOC_INJECT{${m[1]!}}',
    );

    // Step 2: Strip htmlBasePlaceholder -- it's an internal dartdoc artifact
    // that has no meaning in VitePress output.
    text = text.replaceAll(_htmlBasePlaceholder, '');

    // Step 3: Remove paragraph break markers.
    // The `documentation` getter joins multiple documentation sources with
    // `\n\nDARTDOC_PARAGRAPH_BREAK\n\n` (model_element.dart:540).
    // The marker itself is surrounded by newlines, so removing it preserves
    // the paragraph separation without destroying literal `<p>` in content
    // (e.g. "Creates a new `<p>` element").
    text = text.replaceAll('DARTDOC_PARAGRAPH_BREAK', '');

    // Step 4: Strip unresolved {@tool} directives (Flutter-specific).
    // These produce interactive samples in Flutter docs but pass through
    // unresolved when the tool infrastructure is unavailable.
    text = text.replaceAll(_toolDirective, '');

    // Step 5: Strip raw {@inject-html}...{@end-inject-html} directives.
    // When `--inject-html` is not enabled, dartdoc does NOT replace these
    // directives with `<dartdoc-html>` placeholders, so they pass through
    // as raw text. Extract the HTML content between the tags and include
    // it as-is (the user intended it to be HTML output).
    text = text.replaceAllMapped(_rawInjectHtmlDirective, (m) => m[1]!);

    return text;
  }

  /// Resolves `DARTDOC_INJECT{HEXDIGEST}` markers back to actual HTML content.
  ///
  /// Called after markdown rendering, so the injected HTML is NOT processed
  /// by the markdown parser (it's raw HTML passed through to VitePress).
  String _resolveInjectMarkers(String rendered) {
    return rendered.replaceAllMapped(
      _injectMarker,
      (m) => packageGraph.getHtmlFragment(m[1]!) ?? '',
    );
  }

  /// Resolves bracket references in [text] by parsing it through the markdown
  /// parser with a custom `linkResolver`, then serializing the AST back to
  /// markdown.
  ///
  /// This approach correctly handles all edge cases:
  /// - `[operator []]` -- nested brackets
  /// - `` `code with [brackets]` `` -- inline code (not resolved)
  /// - ```` ```dart\n[list]\n``` ```` -- code fences (not resolved)
  /// - `[text](url)` -- existing links (preserved)
  /// - `[a] and [b]` -- multiple refs per line
  String _resolveReferences(String text, ModelElement element) {
    final document = md.Document(
      blockSyntaxes: _blockSyntaxes,
      inlineSyntaxes: _inlineSyntaxes,
      // `encodeHtml: false` is kept for now so that special characters in
      // doc comments (e.g. `&gt;` in code examples) are not double-encoded.
      // HTML tags are escaped in MarkdownRenderer.visitText instead.
      encodeHtml: false,
      linkResolver: (String name, [String? title]) =>
          _resolveLinkReference(name, element),
    );

    final nodes = document.parse(text);
    var rendered = MarkdownRenderer().render(nodes);

    // Resolve inject-html markers AFTER rendering, so the injected HTML
    // bypasses the markdown parser and MarkdownRenderer's tag escaping.
    rendered = _resolveInjectMarkers(rendered);

    // Rewrite hardcoded relative .html links in doc comments (TYPE 2).
    // SDK source code sometimes contains explicit markdown links like
    // `[text](dart-developer/extensionStreamHasListener.html)` that bypass
    // the bracket reference resolution. Convert these to VitePress paths.
    rendered = rendered.replaceAllMapped(_hardcodedHtmlLink, (m) {
      final linkText = m[1]!;
      final path = _convertHtmlPathToVitePress(m[2]!);
      // Empty path means the target has no generated page (e.g. private
      // SDK libraries like dart._http). Render as inline code.
      if (path.isEmpty) return '`$linkText`';
      return '[$linkText]($path)';
    });

    // Rewrite Flutter platform-embedder paths to absolute URLs.
    // SDK doc comments contain links like `[text](/javadoc/...)` and
    // `[text](/ios-embedder/...)` which are hosted on api.flutter.dev,
    // not locally. Without this rewrite they produce broken 404 links.
    rendered = rendered.replaceAllMapped(
      _flutterEmbedderLink,
      (m) => '[${m[1]}](https://api.flutter.dev${m[2]})',
    );

    return sanitizeHtml(rendered, extraAllowedHosts: allowedIframeHosts);
  }

  /// Strips dangerous HTML constructs from rendered documentation and
  /// applies VitePress-specific escaping (Vue template syntax).
  /// - Inline event handlers (`on*=`)
  ///
  /// [extraAllowedHosts] adds hostnames to the built-in whitelist
  /// (YouTube, DartPad). Configured via `allowedIframeHosts` in
  /// `dartdoc_options.yaml`.
  static String sanitizeHtml(
    String html, {
    Set<String> extraAllowedHosts = const {},
  }) {
    // Delegate to format-agnostic core sanitizer.
    html = core_sanitize.sanitizeHtml(
      html,
      extraAllowedHosts: extraAllowedHosts,
    );

    // VitePress-specific: escape Vue template interpolation
    // (VitePress renders markdown as Vue SFC).
    html = html.replaceAll('{{', r'\{\{');
    html = html.replaceAll('}}', r'\}\}');

    return html;
  }

  /// Resolves a single bracket reference `[referenceText]` found in a doc
  /// comment attached to [element].
  ///
  /// Uses the same resolution logic as dartdoc's `getMatchingLinkElement`
  /// function. For local elements, maps to VitePress URLs via
  /// [MarkdownPathResolver]. For external elements (SDK, pub packages),
  /// delegates to the model's built-in [Referable.href] which
  /// already computes correct remote URLs via [Package.baseHref] and the
  /// `linkToUrl`/`linkToRemote` options (matching the original dartdoc
  /// behavior in `_makeLinkNode`).
  ///
  /// Returns an `md.Element('a', ...)` with the resolved href, or `null`
  /// if the reference cannot be resolved (the markdown parser will render it
  /// as plain text).
  md.Node? _resolveLinkReference(String referenceText, ModelElement element) {
    if (referenceText.isEmpty) return null;

    final result = _resolveReference(referenceText, element);
    final linkedElement = result.referable;

    if (linkedElement != null) {
      if (linkedElement is Documentable) {
        final documentable = linkedElement;

        // Guard: private or internal elements have no generated page.
        // Render as inline code instead of producing a broken link.
        if (!_hasPublicPage(documentable)) {
          return md.Element.text('code', referenceText);
        }

        // Escape angle brackets in link text so VitePress/Vue doesn't
        // interpret generic type parameters (e.g. `<Object>`) as HTML
        // component tags.
        final safeText = _escapeLinkText(referenceText);

        // Always try VitePress path first. This handles both local elements
        // AND re-exported elements whose canonical library is in the local
        // package (e.g., `Binder` defined in `modularity_contracts` but
        // re-exported via `modularity_core`).
        final url = paths.linkFor(documentable);
        if (url != null) {
          final anchor = md.Element('a', [md.Text(safeText)]);
          anchor.attributes['href'] = url;
          anchor.attributes['data-resolved'] = '';
          return anchor;
        }

        // Fallback for truly external elements (SDK, pub packages): use
        // the model's built-in href which computes remote URLs via
        // Package.baseHref.
        if (linkedElement.href case var href?) {
          // Strip the htmlBasePlaceholder that dartdoc injects for local
          // packages. For external packages this is a no-op since their
          // href contains a full remote URL.
          href = href.replaceAll(_htmlBasePlaceholder, '');

          // Rewrite relative dartdoc paths to VitePress paths.
          // When linkFor() returns null but href exists, it could be:
          // 1. A .html-suffixed dartdoc path (e.g. `dart-core/int.html`)
          // 2. A relative directory path (e.g. `mylibpub/` for a library)
          // Both need conversion to absolute VitePress paths.
          if (href.isNotEmpty &&
              !href.startsWith('http') &&
              !href.startsWith('/')) {
            if (href.endsWith('.html')) {
              href = _convertHtmlPathToVitePress(href);
            } else {
              // Relative non-.html path (e.g. `mylibpub/`): prepend /api/.
              href = '/api/$href';
            }
          }

          if (href.isNotEmpty) {
            final anchor = md.Element('a', [md.Text(safeText)]);
            anchor.attributes['href'] = href;
            anchor.attributes['data-resolved'] = '';
            return anchor;
          }
        }
      }

      // For non-Documentable referables or elements without URLs, render
      // as inline code.
      return md.Element.text('code', referenceText);
    }

    // Reference not resolved -- render as inline code, matching dartdoc's
    // behavior for unresolved references.
    return md.Element.text('code', referenceText);
  }

  /// Returns `true` if [element] has a public page in the generated output.
  ///
  /// Private elements (names starting with `_`) and elements whose canonical
  /// library is not public will not have generated pages, so linking to them
  /// would produce broken links.
  bool _hasPublicPage(Documentable element) {
    if (!element.isPublic) return false;
    if (element is ModelElement) {
      final lib = element.canonicalLibrary ?? element.library;
      if (lib != null && !lib.isPublic) return false;
    }
    return true;
  }

  /// Escapes `<` and `>` in link display text to prevent VitePress/Vue
  /// from interpreting generic type parameters as HTML tags.
  ///
  /// For example, `DiagnosticsProperty<Object>` becomes
  /// `DiagnosticsProperty\<Object\>` which renders correctly in markdown
  /// without triggering Vue's template compiler.
  static String _escapeLinkText(String text) {
    if (!text.contains('<')) return text;
    return text.replaceAll('<', r'\<').replaceAll('>', r'\>');
  }
}
