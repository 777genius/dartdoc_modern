// Backwards-compatible VitePress facade over the common Markdown processor.
import 'package:dartdoc_modern/src/generator/core/markdown_docs.dart';
import 'package:dartdoc_modern/src/generator/core/path_utils.dart'
    as path_utils;


export 'package:dartdoc_modern/src/generator/core/markdown_docs.dart'
    show MarkdownRenderer;

class VitePressDocProcessor extends MarkdownDocProcessor {
  VitePressDocProcessor(
    super.packageGraph,
    super.paths, {
    super.allowedIframeHosts = const {},
  });

  static String sanitizeHtml(
    String html, {
    Set<String> extraAllowedHosts = const {},
  }) => MarkdownDocProcessor.sanitizeHtml(
    html,
    extraAllowedHosts: extraAllowedHosts,
  );

  static String normalizeSdkLibraryPath(String path) =>
      path_utils.normalizeSdkLibraryPath(path);
}
