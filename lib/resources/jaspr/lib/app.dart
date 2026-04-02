import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/callout.dart';
import 'package:jaspr_content/components/image.dart';
import 'package:jaspr_content/src/content_app.dart';
import 'package:jaspr_content/src/page_extension/heading_anchors_extension.dart';
import 'package:jaspr_content/src/page_extension/table_of_contents_extension.dart';
import 'package:jaspr_content/src/page_parser/markdown_parser.dart';
import 'package:jaspr_content/src/template_engine/template_engine.dart';

import 'components/docs_header.dart';
import 'components/docs_code_block.dart';
import 'components/docs_nav_link.dart';
import 'components/docs_search.dart';
import 'components/docs_sidebar.dart';
import 'components/docs_theme_toggle.dart';
import 'components/dart_pad.dart';
import 'docs_base.dart';
import 'components/mermaid_diagram.dart';
import 'extensions/api_linker_extension.dart';
import 'extensions/base_path_link_extension.dart';
import 'generated/api_sidebar.dart' as api;
import 'generated/guide_sidebar.dart' as guide;
import 'layouts/api_docs_layout.dart';
import 'theme/docs_theme.dart';

Component buildDocsApp({
  required String packageName,
  required DocsThemePreset themePreset,
  String repositoryUrl = '',
  TemplateEngine? templateEngine,
}) {
  final overviewHref = _resolveOverviewHref();
  final hasGuideLinks = guide.guideSidebarGroups.any(
    (group) => group.items.isNotEmpty,
  );

  return ContentApp(
    templateEngine: templateEngine,
    parsers: [MarkdownParser()],
    extensions: [
      const ApiLinkerExtension(),
      HeadingAnchorsExtension(),
      TableOfContentsExtension(),
      const BasePathLinkExtension(),
    ],
    components: [
      Callout(),
      DartPadComponent(),
      MermaidDiagramComponent(),
      DocsCodeBlock(),
      Image(zoom: true),
    ],
    layouts: [
      ApiDocsLayout(
        packageName: packageName,
        header: DocsHeader(
          title: packageName,
          logo: withDocsBasePath('/favicon.svg'),
          homeHref: hasGuideLinks ? '/' : overviewHref,
          navItems: [
            if (hasGuideLinks)
              const DocsHeaderNavItem(
                text: 'Guide',
                href: '/',
                matchPrefix: '/guide',
              ),
            const DocsHeaderNavItem(
              text: 'API Reference',
              href: '/api',
              matchPrefix: '/api',
            ),
          ],
          items: [
            const DocsSearchShell(),
            const DocsThemeToggle(),
            if (repositoryUrl.isNotEmpty)
              DocsNavLink(
                to: repositoryUrl,
                target: Target.blank,
                attributes: {
                  'rel': 'noopener',
                  'aria-label': 'GitHub repository',
                },
                classes: 'header-repo-link',
                children: [Component.text('GitHub')],
              ),
          ],
        ),
        sidebar: DocsSidebar(
          groups: [
            if (!hasGuideLinks)
              DocsSidebarGroup(
                items: [DocsSidebarItem(text: 'Overview', href: overviewHref)],
              ),
            for (final group in guide.guideSidebarGroups) _mapGuideGroup(group),
            for (final group in api.apiSidebarGroups) _mapApiGroup(group),
          ],
        ),
      ),
    ],
    theme: buildDocsTheme(config: DocsThemeConfig.preset(themePreset)),
  );
}

DocsSidebarGroup _mapGuideGroup(guide.SidebarGroup group) {
  return DocsSidebarGroup(
    title: group.title,
    items: [for (final item in group.items) _mapGuideItem(item)],
  );
}

DocsSidebarItem _mapGuideItem(guide.SidebarItem item) {
  return DocsSidebarItem(
    text: item.text,
    href: item.link,
    collapsed: item.collapsed,
    items: [for (final child in item.items) _mapGuideItem(child)],
  );
}

DocsSidebarGroup _mapApiGroup(api.SidebarGroup group) {
  return DocsSidebarGroup(
    title: group.title,
    items: [for (final item in group.items) _mapApiItem(item)],
  );
}

DocsSidebarItem _mapApiItem(api.SidebarItem item) {
  return DocsSidebarItem(
    text: item.text,
    href: item.link,
    collapsed: item.collapsed,
    items: [for (final child in item.items) _mapApiItem(child)],
  );
}

String _resolveOverviewHref() {
  for (final group in guide.guideSidebarGroups) {
    for (final item in group.items) {
      if (item.link case final link? when link.isNotEmpty) return link;
    }
  }

  for (final group in api.apiSidebarGroups) {
    for (final item in group.items) {
      if (item.link case final link? when link.isNotEmpty) return link;
    }
  }

  return '/api';
}
