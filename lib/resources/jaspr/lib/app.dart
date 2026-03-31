import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/callout.dart';
import 'package:jaspr_content/components/code_block.dart';
import 'package:jaspr_content/components/image.dart';
import 'package:jaspr_content/src/content_app.dart';
import 'package:jaspr_content/src/page_extension/heading_anchors_extension.dart';
import 'package:jaspr_content/src/page_extension/table_of_contents_extension.dart';
import 'package:jaspr_content/src/page_parser/markdown_parser.dart';
import 'package:jaspr_content/src/template_engine/template_engine.dart';

import 'components/docs_header.dart';
import 'components/docs_sidebar.dart';
import 'components/docs_theme_toggle.dart';
import 'components/dart_pad.dart';
import 'components/mermaid_diagram.dart';
import 'extensions/api_linker_extension.dart';
import 'generated/api_sidebar.dart' as api;
import 'generated/guide_sidebar.dart' as guide;
import 'layouts/api_docs_layout.dart';
import 'theme/docs_theme.dart';

Component buildDocsApp({
  required String packageName,
  required DocsThemePreset themePreset,
  TemplateEngine? templateEngine,
}) {
  final overviewHref = _resolveOverviewHref();
  final hasGuideLinks = guide.guideSidebarGroups.any((group) => group.items.isNotEmpty);

  return ContentApp(
    templateEngine: templateEngine,
    parsers: [MarkdownParser()],
    extensions: [
      const ApiLinkerExtension(),
      HeadingAnchorsExtension(),
      TableOfContentsExtension(),
    ],
    components: [
      Callout(),
      DartPadComponent(),
      MermaidDiagramComponent(),
      CodeBlock(),
      Image(zoom: true),
    ],
    layouts: [
      ApiDocsLayout(
        packageName: packageName,
        header: DocsHeader(
          title: '$packageName API',
          logo: '/favicon.ico',
          homeHref: overviewHref,
          items: [
            const DocsThemeToggle(),
          ],
        ),
        sidebar: DocsSidebar(
          groups: [
            if (!hasGuideLinks)
              DocsSidebarGroup(
                items: [
                  DocsSidebarItem(text: 'Overview', href: overviewHref),
                ],
              ),
            for (final group in guide.guideSidebarGroups)
              DocsSidebarGroup(
                title: group.title,
                items: [
                  for (final item in group.items)
                    DocsSidebarItem(text: item.text, href: item.link),
                ],
              ),
            for (final group in api.apiSidebarGroups)
              DocsSidebarGroup(
                title: group.title,
                items: [
                  for (final item in group.items)
                    DocsSidebarItem(text: item.text, href: item.link),
                ],
              ),
          ],
        ),
      ),
    ],
    theme: buildDocsTheme(
      config: DocsThemeConfig.preset(themePreset),
    ),
  );
}

String _resolveOverviewHref() {
  for (final group in guide.guideSidebarGroups) {
    for (final item in group.items) {
      if (item.link.isNotEmpty) return item.link;
    }
  }

  for (final group in api.apiSidebarGroups) {
    for (final item in group.items) {
      if (item.link.isNotEmpty) return item.link;
    }
  }

  return '/api';
}
