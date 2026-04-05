import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/callout.dart';
import 'package:jaspr_content/components/image.dart';
import 'package:jaspr_content/components/tabs.dart';
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
import 'extensions/explicit_heading_ids_extension.dart';
import 'generated/api_sidebar.dart' as api;
import 'generated/guide_sidebar.dart' as guide;
import 'layouts/api_docs_layout.dart';
import 'layouts/docs_home_layout.dart';
import 'theme/docs_theme.dart';

const _projectRepositoryUrl = 'https://github.com/777genius/dartdoc_modern';
const _projectVitePressDocsUrl =
    'https://777genius.github.io/dartdoc_modern/vitepress/';
const _projectJasprDocsUrl =
    'https://777genius.github.io/dartdoc_modern/jaspr/';

Component buildDocsApp({
  required String packageName,
  required DocsThemePreset themePreset,
  String repositoryUrl = '',
  TemplateEngine? templateEngine,
}) {
  final guideLandingHref = _resolveGuideLandingHref();
  final overviewHref = guideLandingHref ?? _resolveOverviewHref();
  final hasGuideLinks = guide.guideSidebarGroups.any(
    (group) => group.items.isNotEmpty,
  );
  final guideNavHref = guideLandingHref ?? '/api';
  final primaryHomeActionHref = guideLandingHref ?? '/api';
  final isProjectDocs =
      packageName == 'dartdoc_modern' ||
      repositoryUrl == _projectRepositoryUrl;
  final headerItems = _buildHeaderItems(
    isProjectDocs: isProjectDocs,
    repositoryUrl: repositoryUrl,
  );

  return ContentApp(
    templateEngine: templateEngine,
    parsers: const [MarkdownParser()],
    extensions: [
      const ApiLinkerExtension(),
      const ExplicitHeadingIdsExtension(),
      HeadingAnchorsExtension(),
      TableOfContentsExtension(),
      const BasePathLinkExtension(),
    ],
    components: [
      Callout(),
      const Tabs(),
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
          homeHref: '/',
          navItems: [
            if (hasGuideLinks)
              DocsHeaderNavItem(
                text: 'Guide',
                href: guideNavHref,
                matchPrefix: '/guide',
              ),
            const DocsHeaderNavItem(
              text: 'API Reference',
              href: '/api',
              matchPrefix: '/api',
            ),
          ],
          items: headerItems,
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
      DocsHomeLayout(
        packageName: packageName,
        primaryActionHref: primaryHomeActionHref,
        apiHref: '/api',
        hasGuideLinks: hasGuideLinks,
        header: DocsHeader(
          title: packageName,
          logo: withDocsBasePath('/favicon.svg'),
          homeHref: '/',
          navItems: [
            if (hasGuideLinks)
              DocsHeaderNavItem(
                text: 'Guide',
                href: guideNavHref,
                matchPrefix: '/guide',
              ),
            const DocsHeaderNavItem(
              text: 'API Reference',
              href: '/api',
              matchPrefix: '/api',
            ),
          ],
          items: headerItems,
        ),
      ),
    ],
    theme: buildDocsTheme(config: DocsThemeConfig.preset(themePreset)),
  );
}

const _githubIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 .5C5.65.5.5 5.65.5 12c0 5.09 3.29 9.41 7.86 10.94.58.11.79-.25.79-.56 0-.28-.01-1.02-.02-2-3.2.69-3.88-1.54-3.88-1.54-.52-1.33-1.28-1.68-1.28-1.68-1.05-.71.08-.69.08-.69 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.71 1.26 3.37.97.1-.75.4-1.26.72-1.55-2.55-.29-5.24-1.27-5.24-5.68 0-1.25.45-2.27 1.18-3.07-.12-.29-.51-1.45.11-3.02 0 0 .96-.31 3.14 1.17a10.9 10.9 0 0 1 5.72 0c2.18-1.48 3.14-1.17 3.14-1.17.62 1.57.23 2.73.11 3.02.74.8 1.18 1.82 1.18 3.07 0 4.42-2.69 5.39-5.26 5.67.41.35.78 1.04.78 2.1 0 1.52-.01 2.75-.01 3.12 0 .31.21.68.8.56A11.52 11.52 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5Z"></path></svg>
''';

List<Component> _buildHeaderItems({
  required bool isProjectDocs,
  required String repositoryUrl,
}) {
  return [
    if (isProjectDocs)
      _buildExternalHeaderLink(
        text: 'Jaspr',
        href: _projectJasprDocsUrl,
        ariaLabel: 'Jaspr docs version',
      ),
    if (isProjectDocs)
      _buildExternalHeaderLink(
        text: 'VitePress',
        href: _projectVitePressDocsUrl,
        ariaLabel: 'VitePress docs version',
      ),
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
        children: [
          span(classes: 'header-repo-link-icon', [
            RawText(_githubIcon),
          ]),
        ],
      ),
  ];
}

Component _buildExternalHeaderLink({
  required String text,
  required String href,
  required String ariaLabel,
}) {
  return DocsNavLink(
    to: href,
    target: Target.blank,
    attributes: {
      'rel': 'noopener',
      'aria-label': ariaLabel,
    },
    classes: 'header-repo-link',
    children: [Component.text(text)],
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
  final guideLandingHref = _resolveGuideLandingHref();
  if (guideLandingHref != null) {
    return guideLandingHref;
  }

  for (final group in api.apiSidebarGroups) {
    for (final item in group.items) {
      if (item.link case final link? when link.isNotEmpty) return link;
    }
  }

  return '/api';
}

String? _resolveGuideLandingHref() {
  for (final group in guide.guideSidebarGroups) {
    final firstLink = _firstGuideLink(group.items);
    if (firstLink != null) return firstLink;
  }
  return null;
}

String? _firstGuideLink(List<guide.SidebarItem> items) {
  for (final item in items) {
    if (item.link case final link? when link.isNotEmpty) {
      return link;
    }
    final nested = _firstGuideLink(item.items);
    if (nested != null) return nested;
  }
  return null;
}
