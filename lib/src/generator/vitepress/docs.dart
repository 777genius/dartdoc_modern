// Backwards-compatible VitePress facade over the common Markdown processor.
import 'package:dartdoc_modern/src/generator/core/markdown_docs.dart';
import 'package:dartdoc_modern/src/generator/vitepress/paths.dart';
import 'package:dartdoc_modern/src/model/model.dart';

export 'package:dartdoc_modern/src/generator/core/markdown_docs.dart'
    show MarkdownRenderer;

class VitePressDocProcessor extends MarkdownDocProcessor {
  VitePressDocProcessor(
    PackageGraph packageGraph,
    VitePressPathResolver paths, {
    Set<String> allowedIframeHosts = const {},
  }) : super(
         packageGraph,
         paths,
         allowedIframeHosts: allowedIframeHosts,
       );

  static String sanitizeHtml(
    String html, {
    Set<String> extraAllowedHosts = const {},
  }) => MarkdownDocProcessor.sanitizeHtml(
    html,
    extraAllowedHosts: extraAllowedHosts,
  );

  static String normalizeSdkLibraryPath(String path) =>
      MarkdownDocProcessor.normalizeSdkLibraryPath(path);
}
