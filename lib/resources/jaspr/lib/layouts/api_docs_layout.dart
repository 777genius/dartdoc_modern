import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

import '../components/docs_dartpad_runtime.dart';
import '../components/docs_nav_link.dart';
import '../components/docs_mermaid_runtime.dart';
import '../components/docs_search.dart';

class ApiDocsLayout extends DocsLayout {
  const ApiDocsLayout({
    required this.packageName,
    super.sidebar,
    super.header,
    super.footer,
  });

  final String packageName;

  @override
  Iterable<Component> buildHead(Page page) sync* {
    yield* super.buildHead(page);
    yield Style(styles: _styles);
    yield script(
      src: 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js',
      defer: true,
    );
  }

  @override
  Component buildBody(Page page, Component child) {
    final pageData = page.data.page;
    final breadcrumb = _buildBreadcrumb(page, pageData);
    final collapsibleOutline = pageData['outlineCollapsible'] == true;
    final pageTitle = pageData['title'] as String?;
    final pageDescription = pageData['description'] as String?;
    final pageImage = pageData['image'] as String?;
    final pageImageAlt = pageData['imageAlt'] as String?;
    final hasContentHeader = (pageTitle?.isNotEmpty ?? false) ||
        (pageDescription?.isNotEmpty ?? false) ||
        (pageImage?.isNotEmpty ?? false);

    return div(classes: 'docs', [
      const DocsDartPadRuntime(),
      const DocsMermaidRuntime(),
      if (this.header case final Component header)
        div(classes: 'header-container', attributes: {
          if (this.sidebar != null) 'data-has-sidebar': '',
        }, [
          header,
          const DocsSearchShell(),
        ]),
      div(classes: 'main-container', [
        div(
          classes: 'sidebar-barrier',
          attributes: {'role': 'button', 'data-docs-sidebar-barrier': 'true'},
          [],
        ),
        if (this.sidebar case final Component sidebar)
          div(classes: 'sidebar-container', [
            sidebar,
          ]),
        main_([
            div([
            div(classes: 'content-container', [
              if (breadcrumb != null) breadcrumb,
              if (hasContentHeader)
                div(classes: 'content-header', [
                  if (pageTitle != null && pageTitle.isNotEmpty)
                    h1([Component.text(pageTitle)]),
                  if (pageDescription != null && pageDescription.isNotEmpty)
                    p([Component.text(pageDescription)]),
                  if (pageImage != null && pageImage.isNotEmpty)
                    img(src: pageImage, alt: pageImageAlt),
                ]),
              child,
              if (this.footer != null)
                div(classes: 'content-footer', [this.footer!]),
            ]),
            aside(classes: 'toc', [
              if (page.data['toc'] case final TableOfContents toc)
                div([
                  h3([Component.text('On this page')]),
                  _buildToc(toc, page.url, collapsibleOutline),
                ]),
            ]),
          ]),
        ]),
      ]),
    ]);
  }

  Component? _buildBreadcrumb(Page page, Map<String, Object?> pageData) {
    final sourceUrl = pageData['sourceUrl'] as String?;
    final trail = <Component>[];
    final path = page.path.replaceAll('\\', '/');
    final segments = path.split('/');
    final pageTitle = pageData['title'] as String? ?? '';

    if (path.startsWith('api/') && segments.length >= 3) {
      final libraryDir = segments[1];
      final libraryName = (pageData['library'] as String?) ??
          (segments.length == 3 ? pageTitle : libraryDir);
      final isLibraryOverview =
          segments.length == 3 && segments.last == 'index.md';

      if (isLibraryOverview) {
        trail.addAll([
          DocsNavLink(
            to: '/api',
            classes: 'breadcrumb-link',
            children: [Component.text(packageName)],
          ),
          _separator(),
          span(classes: 'breadcrumb-current', [Component.text(libraryName)]),
        ]);
      } else if (pageData['category'] case final String category) {
        trail.addAll([
          DocsNavLink(
            to: '/api/$libraryDir',
            classes: 'breadcrumb-link',
            children: [Component.text(libraryName)],
          ),
          _separator(),
          span(classes: 'breadcrumb-category', [Component.text(category)]),
          if (pageTitle.isNotEmpty) ...[
            _separator(),
            span(classes: 'breadcrumb-current', [Component.text(pageTitle)]),
          ],
        ]);
      }
    } else if (path.startsWith('guide/') && pageTitle.isNotEmpty) {
      trail.addAll([
        DocsNavLink(
          to: '/',
          classes: 'breadcrumb-link',
          children: [Component.text('Guides')],
        ),
        _separator(),
        span(classes: 'breadcrumb-current', [Component.text(pageTitle)]),
      ]);
    }

    if (trail.isEmpty && sourceUrl == null) return null;

    return div(classes: 'api-breadcrumb', [
      div(classes: 'breadcrumb-trail', trail),
      if (sourceUrl != null)
        div(classes: 'breadcrumb-actions', [
          DocsNavLink(
            to: sourceUrl,
            target: Target.blank,
            attributes: {'rel': 'noopener'},
            classes: 'action-btn',
            children: [Component.text('Source')],
          ),
        ]),
    ]);
  }

  Component _buildToc(
    TableOfContents toc,
    String baseUrl,
    bool collapsible,
  ) {
    if (!collapsible) {
      return ul([
        for (final entry in toc.entries) ..._buildFlatToc(entry, baseUrl),
      ]);
    }

    return ul([
      for (final entry in toc.entries) _buildCollapsibleEntry(entry, baseUrl),
    ]);
  }

  Iterable<Component> _buildFlatToc(TocEntry entry, String baseUrl) sync* {
    yield li([
      DocsNavLink(
        to: '$baseUrl#${entry.id}',
        children: [Component.text(entry.text)],
      ),
      if (entry.children.isNotEmpty)
        ul([
          for (final child in entry.children) ..._buildFlatToc(child, baseUrl),
        ]),
    ]);
  }

  Component _buildCollapsibleEntry(TocEntry entry, String baseUrl) {
    if (entry.children.isEmpty) {
      return li([
        DocsNavLink(
          to: '$baseUrl#${entry.id}',
          children: [Component.text(entry.text)],
        ),
      ]);
    }

    return li([
      details(classes: 'toc-section', [
        summary([
          DocsNavLink(
            to: '$baseUrl#${entry.id}',
            children: [Component.text(entry.text)],
          ),
        ]),
        ul([
          for (final child in entry.children)
            _buildCollapsibleEntry(child, baseUrl),
        ]),
      ]),
    ]);
  }

  Component _separator() => span(
        classes: 'breadcrumb-separator',
        [Component.text('›')],
      );

  static List<StyleRule> get _styles => [
        css('.header-container').styles(
          position: Position.sticky(top: Unit.zero),
          zIndex: ZIndex(20),
          backgroundColor: ContentColors.background,
          border: Border.only(
            bottom: BorderSide(
              width: 1.px,
              color: Color('var(--docs-shell-border)'),
            ),
          ),
        ),
        css('[data-docs-nav-loading] body, [data-docs-nav-loading] .main-container')
            .styles(
          raw: {
            'cursor': 'progress',
          },
        ),
        css('.theme-toggle').styles(
          border: Border.all(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
          radius: BorderRadius.circular(999.px),
          backgroundColor: Color('var(--docs-shell-surface-soft)'),
          color: ContentColors.text,
        ),
        css('.theme-toggle:hover').styles(
          backgroundColor: Color('var(--docs-shell-accent-soft)'),
          border: Border.all(
            width: 1.px,
            color: Color('var(--docs-shell-border-strong)'),
          ),
        ),
        css('.api-breadcrumb', [
          css('&').styles(
            display: Display.flex,
            justifyContent: JustifyContent.spaceBetween,
            alignItems: AlignItems.center,
            margin: Margin.only(bottom: 1.rem),
            color: ContentColors.text,
            gap: Gap.row(1.rem),
          ),
          css('.breadcrumb-trail').styles(
            display: Display.flex,
            alignItems: AlignItems.center,
            flexWrap: FlexWrap.wrap,
          ),
          css('.breadcrumb-link').styles(
            color: Color('var(--docs-shell-accent)'),
            textDecoration: TextDecoration.none,
          ),
          css('.breadcrumb-link:hover').styles(
            textDecoration: TextDecoration(line: TextDecorationLine.underline),
          ),
          css('.breadcrumb-separator').styles(
            opacity: 0.6,
            margin: Margin.symmetric(horizontal: 0.5.rem),
          ),
          css('.breadcrumb-category').styles(opacity: 0.85),
          css('.breadcrumb-current').styles(fontWeight: FontWeight.w600),
          css('.breadcrumb-actions').styles(
            display: Display.flex,
            alignItems: AlignItems.center,
          ),
          css('.action-btn').styles(
            color: Color('var(--docs-shell-accent)'),
            textDecoration: TextDecoration.none,
            fontWeight: FontWeight.w600,
          ),
        ]),
        css('.header-search-shell', [
          css('&').styles(
            display: Display.flex,
            justifyContent: JustifyContent.end,
            padding:
                Padding.only(left: 1.5.rem, right: 1.5.rem, bottom: 0.85.rem),
          ),
          css('.search-launcher').styles(
            display: Display.flex,
            justifyContent: JustifyContent.spaceBetween,
            alignItems: AlignItems.center,
            gap: Gap.column(0.8.rem),
            minWidth: 13.25.rem,
            padding:
                Padding.symmetric(vertical: 0.68.rem, horizontal: 0.92.rem),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border-strong)'),
            ),
            radius: BorderRadius.circular(999.px),
            backgroundColor: Color('var(--docs-shell-surface-soft)'),
            cursor: Cursor.pointer,
            color: ContentColors.text,
            transition: Transition(
              'border-color, background-color, transform',
              duration: Duration(milliseconds: 150),
            ),
          ),
          css('.search-launcher:hover').styles(
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-accent)'),
            ),
            backgroundColor: Color('var(--docs-shell-accent-soft)'),
            raw: {'transform': 'translateY(-1px)'},
          ),
          css('.search-launcher:focus-visible').styles(
            outline: Outline(
              width: OutlineWidth(3.px),
              style: OutlineStyle.solid,
              color: Color('var(--docs-shell-focus)'),
              offset: 2.px,
            ),
          ),
          css('.search-launcher-label').styles(fontWeight: FontWeight.w600),
          css('.search-launcher-shortcut').styles(
            fontSize: 0.85.rem,
            opacity: 0.7,
            padding:
                Padding.symmetric(vertical: 0.18.rem, horizontal: 0.45.rem),
            radius: BorderRadius.circular(999.px),
            backgroundColor: Color('var(--docs-shell-surface-elevated)'),
            raw: {'line-height': '1'},
          ),
          css.media(MediaQuery.all(maxWidth: 767.px), [
            css('&').styles(
              justifyContent: JustifyContent.stretch,
              padding:
                  Padding.only(left: 1.rem, right: 1.rem, bottom: 0.75.rem),
            ),
            css('.search-launcher').styles(
              minWidth: Unit.zero,
              width: 100.percent,
            ),
          ]),
        ]),
        css('[data-theme="dark"] .header-search-shell .search-launcher-shortcut')
            .styles(opacity: 0.6),
        css('.docs-search-overlay', [
          css('&').styles(
            position: Position.fixed(
              top: Unit.zero,
              left: Unit.zero,
              right: Unit.zero,
              bottom: Unit.zero,
            ),
            zIndex: ZIndex(60),
          ),
          css('&[hidden]').styles(display: Display.none),
          css('.docs-search-backdrop').styles(
            position: Position.absolute(
              top: Unit.zero,
              left: Unit.zero,
              right: Unit.zero,
              bottom: Unit.zero,
            ),
            backgroundColor: Color('var(--docs-shell-overlay)'),
          ),
          css('.docs-search-panel').styles(
            position: Position.relative(),
            margin: Margin.only(top: 8.vh),
            width: 100.percent,
            maxWidth: 44.rem,
            backgroundColor: Color('var(--docs-shell-surface-elevated)'),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border)'),
            ),
            radius: BorderRadius.circular(1.rem),
            shadow: BoxShadow(
              offsetX: Unit.zero,
              offsetY: Unit.zero,
              blur: 40.px,
              color: Color('var(--docs-shell-shadow)'),
            ),
            overflow: Overflow.hidden,
            raw: {
              'margin-left': 'auto',
              'margin-right': 'auto',
              'backdrop-filter': 'blur(18px)',
              '-webkit-backdrop-filter': 'blur(18px)',
            },
          ),
          css('.docs-search-header').styles(
            display: Display.flex,
            alignItems: AlignItems.center,
            flexWrap: FlexWrap.wrap,
            gap: Gap.column(0.65.rem),
            padding: Padding.only(top: 0.95.rem, right: 0.95.rem, bottom: 0.85.rem, left: 0.95.rem),
            border: Border.only(
              bottom: BorderSide(
                width: 1.px,
                color: Color('var(--docs-shell-border)'),
              ),
            ),
          ),
          css('.docs-search-heading').styles(
            width: 100.percent,
            fontSize: 0.84.rem,
            fontWeight: FontWeight.w800,
            textTransform: TextTransform.upperCase,
            color: Color('var(--docs-shell-muted)'),
            raw: {'letter-spacing': '0.12em'},
          ),
          css('.docs-search-input').styles(
            width: 100.percent,
            padding: Padding.symmetric(vertical: 0.78.rem, horizontal: 0.92.rem),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border-strong)'),
            ),
            radius: BorderRadius.circular(0.75.rem),
            backgroundColor: Color('var(--docs-shell-surface-soft)'),
            color: ContentColors.text,
          ),
          css('.docs-search-input:focus-visible').styles(
            outline: Outline(
              width: OutlineWidth(3.px),
              style: OutlineStyle.solid,
              color: Color('var(--docs-shell-focus)'),
              offset: 1.px,
            ),
          ),
          css('.docs-search-close').styles(
            padding: Padding.symmetric(vertical: 0.45.rem, horizontal: 0.7.rem),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border-strong)'),
            ),
            radius: BorderRadius.circular(0.75.rem),
            backgroundColor: Color('var(--docs-shell-surface-soft)'),
            cursor: Cursor.pointer,
            color: ContentColors.text,
          ),
          css('.docs-search-close:hover').styles(
            backgroundColor: Color('var(--docs-shell-accent-soft)'),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-accent)'),
            ),
          ),
          css('.docs-search-status').styles(
            padding: Padding.symmetric(vertical: 0.65.rem, horizontal: 0.95.rem),
            fontSize: 0.88.rem,
            color: Color('var(--docs-shell-muted)'),
          ),
          css('.docs-search-results').styles(
            maxHeight: 65.vh,
            overflow: Overflow.auto,
            padding: Padding.only(bottom: 0.35.rem),
          ),
          css('.docs-search-footer').styles(
            display: Display.flex,
            justifyContent: JustifyContent.spaceBetween,
            alignItems: AlignItems.center,
            flexWrap: FlexWrap.wrap,
            gap: Gap.row(0.75.rem),
            padding: Padding.symmetric(vertical: 0.72.rem, horizontal: 0.95.rem),
            border: Border.only(
              top: BorderSide(
                width: 1.px,
                color: Color('var(--docs-shell-border)'),
              ),
            ),
            backgroundColor: Color('var(--docs-shell-surface-soft)'),
          ),
          css('.docs-search-hints').styles(
            display: Display.flex,
            alignItems: AlignItems.center,
            flexWrap: FlexWrap.wrap,
            gap: Gap.column(0.45.rem),
          ),
          css('.docs-search-key').styles(
            display: Display.inlineFlex,
            justifyContent: JustifyContent.center,
            alignItems: AlignItems.center,
            minWidth: 2.rem,
            padding:
                Padding.symmetric(vertical: 0.22.rem, horizontal: 0.4.rem),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border-strong)'),
            ),
            radius: BorderRadius.circular(0.5.rem),
            backgroundColor: Color('var(--docs-shell-surface-elevated)'),
            color: ContentColors.text,
            fontSize: 0.76.rem,
            fontWeight: FontWeight.w700,
            shadow: BoxShadow(
              offsetX: Unit.zero,
              offsetY: 10.px,
              blur: 24.px,
              color: Color('var(--docs-shell-shadow)'),
            ),
          ),
          css('.docs-search-hint-label, .docs-search-footnote').styles(
            fontSize: 0.82.rem,
            color: Color('var(--docs-shell-muted)'),
          ),
          css('.docs-search-result').styles(
            display: Display.flex,
            gap: Gap.column(1.rem),
            padding: Padding.symmetric(vertical: 0.78.rem, horizontal: 0.95.rem),
            textDecoration: TextDecoration.none,
            color: ContentColors.text,
            border: Border.only(
              bottom: BorderSide(
                width: 1.px,
                color: Color('var(--docs-shell-border)'),
              ),
            ),
            transition: Transition(
              'background-color, border-color, transform, box-shadow',
              duration: Duration(milliseconds: 150),
            ),
          ),
          css('.docs-search-result:hover').styles(
            backgroundColor: Color('var(--docs-shell-accent-soft)'),
            raw: {'transform': 'translateY(-1px)'},
          ),
          css('.docs-search-result.active').styles(
            backgroundColor: Color('var(--docs-shell-accent-soft)'),
            border: Border.only(
              bottom: BorderSide(
                width: 1.px,
                color: Color('var(--docs-shell-accent)'),
              ),
            ),
            shadow: BoxShadow(
              offsetX: Unit.zero,
              offsetY: 16.px,
              blur: 28.px,
              color: Color('var(--docs-shell-shadow)'),
            ),
            raw: {
              'outline': '1px solid var(--docs-shell-accent)',
              'box-shadow':
                  'inset 3px 0 0 var(--docs-shell-accent), 0 16px 28px var(--docs-shell-shadow)',
            },
          ),
          css('.docs-search-result:focus-visible').styles(
            outline: Outline(
              width: OutlineWidth(3.px),
              style: OutlineStyle.solid,
              color: Color('var(--docs-shell-focus)'),
            ),
            raw: {'outline-offset': '-2px'},
          ),
          css('.docs-search-result-section').styles(
            backgroundColor: Color('var(--docs-shell-surface-soft)'),
          ),
          css('.docs-search-kind').styles(
            display: Display.inlineFlex,
            justifyContent: JustifyContent.center,
            alignItems: AlignItems.center,
            minWidth: 3.5.rem,
            padding:
                Padding.symmetric(vertical: 0.28.rem, horizontal: 0.55.rem),
            fontSize: 0.72.rem,
            fontWeight: FontWeight.w700,
            textTransform: TextTransform.upperCase,
            radius: BorderRadius.circular(999.px),
            backgroundColor: Color('var(--docs-shell-accent-soft)'),
            color: Color('var(--docs-shell-accent-strong)'),
          ),
          css('.docs-search-meta').styles(flex: Flex(grow: 1)),
          css('.docs-search-topline').styles(
            display: Display.flex,
            justifyContent: JustifyContent.spaceBetween,
            alignItems: AlignItems.center,
            flexWrap: FlexWrap.wrap,
            gap: Gap.row(0.6.rem),
            margin: Margin.only(bottom: 0.35.rem),
          ),
          css('.docs-search-title').styles(
            fontWeight: FontWeight.w700,
            margin: Margin.only(bottom: 0.24.rem),
          ),
          css('.docs-search-title mark, .docs-search-summary mark').styles(
            backgroundColor: Color('var(--docs-shell-accent-soft)'),
            color: Color('var(--docs-shell-accent-strong)'),
            radius: BorderRadius.circular(0.35.rem),
            padding:
                Padding.symmetric(vertical: 0.04.rem, horizontal: 0.16.rem),
            raw: {
              'box-decoration-break': 'clone',
              '-webkit-box-decoration-break': 'clone',
            },
          ),
          css('.docs-search-section').styles(
            fontWeight: FontWeight.w500,
            opacity: 0.8,
            margin: Margin.only(left: 0.35.rem),
          ),
          css('.docs-search-url').styles(
            fontSize: 0.8.rem,
            color: Color('var(--docs-shell-muted)'),
          ),
          css('.docs-search-summary').styles(
            fontSize: 0.89.rem,
            opacity: 0.9,
            raw: {'line-height': '1.45'},
          ),
          css('.docs-search-kind-guide').styles(
            backgroundColor: Color('var(--docs-shell-surface-elevated)'),
            color: Color('var(--docs-shell-accent)'),
          ),
          css('.docs-search-kind-page').styles(
            backgroundColor: Color('var(--docs-shell-surface-elevated)'),
            color: Color('var(--docs-shell-accent)'),
          ),
          css('.docs-search-kind-section').styles(
            backgroundColor: Color('var(--docs-shell-callout-bg)'),
            color: Color('var(--docs-shell-accent-strong)'),
          ),
          css.media(MediaQuery.all(maxWidth: 767.px), [
            css('.docs-search-panel').styles(
              margin: Margin.only(top: 2.5.vh),
              maxWidth: 100.percent,
              raw: {
                'margin-left': '0.55rem',
                'margin-right': '0.55rem',
              },
            ),
            css('.docs-search-header').styles(
              display: Display.block,
            ),
            css('.docs-search-heading').styles(
              margin: Margin.only(bottom: 0.8.rem),
            ),
            css('.docs-search-close').styles(
              margin: Margin.only(top: 0.65.rem),
            ),
            css('.docs-search-footer').styles(
              display: Display.block,
            ),
            css('.docs-search-footnote').styles(
              display: Display.block,
              margin: Margin.only(top: 0.65.rem),
            ),
            css('.docs-search-result').styles(
              display: Display.block,
            ),
            css('.docs-search-kind').styles(
              margin: Margin.only(bottom: 0.4.rem),
            ),
            css('.docs-search-topline').styles(
              display: Display.block,
            ),
            css('.docs-search-url').styles(
              margin: Margin.only(top: 0.3.rem),
            ),
          ]),
        ]),
        css('.toc .toc-section', [
          css('&').styles(margin: Margin.only(bottom: 0.5.rem)),
          css('summary').styles(cursor: Cursor.pointer),
          css('summary a').styles(textDecoration: TextDecoration.none),
          css('ul').styles(margin: Margin.only(top: 0.35.rem, left: 0.75.rem)),
        ]),
        css('.content blockquote', [
          css('&').styles(
            margin: Margin.only(top: 1.rem, bottom: 1.25.rem),
            padding: Padding.only(
              top: 0.9.rem,
              right: 1.rem,
              bottom: 0.9.rem,
              left: 1.2.rem,
            ),
            border: Border.only(
              left: BorderSide(
                width: 4.px,
                color: Color('var(--docs-shell-callout-border)'),
              ),
            ),
            backgroundColor: Color('var(--docs-shell-callout-bg)'),
            radius: BorderRadius.circular(0.75.rem),
            color: ContentColors.text,
            raw: {'font-style': 'normal'},
          ),
          css('p').styles(margin: Margin.only(top: 0.35.rem, bottom: 0.35.rem)),
          css('p:first-of-type').styles(margin: Margin.only(top: Unit.zero)),
          css('p:last-of-type').styles(margin: Margin.only(bottom: Unit.zero)),
          css('strong').styles(fontWeight: FontWeight.w700),
        ]),
        css('.code-block', [
          css('&').styles(position: Position.relative()),
          css('button').styles(
            position: Position.absolute(top: 0.75.rem, right: 0.75.rem),
            display: Display.inlineFlex,
            justifyContent: JustifyContent.center,
            alignItems: AlignItems.center,
            width: 2.rem,
            height: 2.rem,
            padding: Padding.zero,
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border-strong)'),
            ),
            radius: BorderRadius.circular(0.5.rem),
            backgroundColor: Color('var(--docs-shell-code-button-bg)'),
            color: Color('var(--docs-shell-code-button-fg)'),
            opacity: 0,
            zIndex: ZIndex(10),
            cursor: Cursor.pointer,
            transition: Transition(
              'opacity',
              duration: Duration(milliseconds: 150),
            ),
          ),
          css('&:hover button').styles(opacity: 1),
          css('pre').styles(margin: Margin.zero),
        ]),
        css('.dartpad-wrapper', [
          css('&').styles(
            margin: Margin.only(top: 1.rem, bottom: 1.25.rem),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border-strong)'),
            ),
            radius: BorderRadius.circular(0.75.rem),
            overflow: Overflow.hidden,
            backgroundColor: Color('var(--docs-shell-surface-soft)'),
          ),
          css('.dartpad-preview pre').styles(
            margin: Margin.zero,
            padding: Padding.all(1.rem),
            backgroundColor: ContentColors.preBg,
            overflow: Overflow.auto,
          ),
          css('.dartpad-toolbar').styles(
            display: Display.flex,
            gap: Gap.column(0.5.rem),
            padding: Padding.all(0.75.rem),
            border: Border.only(
              top: BorderSide(
                width: 1.px,
                color: Color('var(--docs-shell-border)'),
              ),
            ),
          ),
          css('.dartpad-btn').styles(
            padding:
                Padding.symmetric(vertical: 0.45.rem, horizontal: 0.75.rem),
            backgroundColor: Color('var(--docs-shell-accent)'),
            color: Colors.white,
            radius: BorderRadius.circular(0.5.rem),
            textDecoration: TextDecoration.none,
            border: Border.unset,
            cursor: Cursor.pointer,
          ),
          css('.dartpad-btn:hover').styles(
            backgroundColor: Color('var(--docs-shell-accent-strong)'),
          ),
          css('.dartpad-open').styles(
            backgroundColor: Color('var(--docs-shell-surface-elevated)'),
            color: ContentColors.text,
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border-strong)'),
            ),
          ),
          css('.dartpad-stage').styles(
            backgroundColor: Color('var(--docs-shell-dartpad-stage)'),
          ),
          css('.dartpad-iframe').styles(
            width: 100.percent,
            border: Border.unset,
            display: Display.block,
          ),
        ]),
        css('.mermaid-diagram', [
          css('&').styles(
            margin: Margin.only(top: 1.rem, bottom: 1.25.rem),
            overflow: Overflow.auto,
          ),
          css('svg').styles(maxWidth: 100.percent),
        ]),
        css('.docs', [
          css('&').styles(
            backgroundColor: ContentColors.background,
            raw: {
              'background-image':
                  'radial-gradient(circle at top left, var(--docs-shell-accent-soft) 0, transparent 30rem), radial-gradient(circle at top right, var(--docs-shell-accent-soft) 0, transparent 24rem)',
            },
          ),
          css('.main-container').styles(
            maxWidth: 100.percent,
            margin: Margin.zero,
          ),
          css('main').styles(
            width: 100.percent,
          ),
          css('main > div').styles(
            display: Display.grid,
            raw: {
              'grid-template-columns': 'minmax(0, 1fr) 18rem',
              'gap': '2.25rem',
              'max-width': 'min(96rem, calc(100vw - 3rem))',
              'margin': '0 auto',
              'padding': '1.5rem 0 3.5rem',
            },
          ),
          css.media(MediaQuery.all(maxWidth: 1180.px), [
            css('main > div').styles(
              raw: {
                'grid-template-columns': 'minmax(0, 1fr) 16rem',
                'gap': '1.5rem',
                'max-width': 'calc(100vw - 2rem)',
              },
            ),
          ]),
          css.media(MediaQuery.all(maxWidth: 959.px), [
            css('main > div').styles(
              display: Display.block,
              padding: Padding.only(top: 1.rem, right: 1.rem, bottom: 2.rem, left: 1.rem),
            ),
          ]),
        ]),
        css('.header-container', [
          css('&').styles(
            position: Position.sticky(top: Unit.zero),
            zIndex: ZIndex(40),
            raw: {
              'backdrop-filter': 'blur(20px)',
              '-webkit-backdrop-filter': 'blur(20px)',
              'background':
                  'color-mix(in srgb, var(--background) 84%, transparent)',
              'box-shadow': '0 20px 45px -36px var(--docs-shell-shadow)',
            },
          ),
          css('[data-has-sidebar] .header').styles(
            maxWidth: 96.rem,
            margin: Margin.zero,
            padding: Padding.only(top: 1.rem, right: 1.5.rem, bottom: 0.75.rem, left: 1.5.rem),
            raw: {
              'margin-left': 'auto',
              'margin-right': 'auto',
            },
          ),
          css('.header .header-title').styles(
            fontWeight: FontWeight.w800,
            raw: {
              'letter-spacing': '-0.03em',
            },
          ),
          css('.header .header-logo').styles(
            radius: BorderRadius.circular(1.rem),
            backgroundColor: Color('var(--docs-shell-accent-soft)'),
            padding: Padding.all(0.35.rem),
          ),
        ]),
        css('.theme-toggle').styles(
          shadow: BoxShadow(
            offsetX: Unit.zero,
            offsetY: 14.px,
            blur: 28.px,
            color: Color('var(--docs-shell-shadow)'),
          ),
          transition: Transition(
            'background-color, border-color, transform, box-shadow',
            duration: Duration(milliseconds: 170),
          ),
        ),
        css('.theme-toggle:hover').styles(
          raw: {'transform': 'translateY(-1px)'},
          shadow: BoxShadow(
            offsetX: Unit.zero,
            offsetY: 20.px,
            blur: 34.px,
            color: Color('var(--docs-shell-shadow)'),
          ),
        ),
        css('.sidebar-container', [
          css('&').styles(
            alignSelf: AlignSelf.start,
            padding: Padding.only(top: 1.4.rem, left: 1.rem, right: 0.5.rem, bottom: 2.rem),
          ),
          css('.sidebar').styles(
            position: Position.sticky(top: 7.5.rem),
            maxHeight: 84.vh,
            overflow: Overflow.auto,
            padding: Padding.all(1.rem),
            radius: BorderRadius.circular(1.15.rem),
            backgroundColor: Color('var(--docs-shell-surface)'),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border)'),
            ),
            shadow: BoxShadow(
              offsetX: Unit.zero,
              offsetY: 24.px,
              blur: 45.px,
              color: Color('var(--docs-shell-shadow)'),
            ),
          ),
          css('.sidebar .sidebar-header').styles(
            margin: Margin.only(bottom: 1.rem),
            padding: Padding.only(bottom: 0.9.rem),
            border: Border.only(
              bottom: BorderSide(
                width: 1.px,
                color: Color('var(--docs-shell-border)'),
              ),
            ),
          ),
          css('.sidebar .sidebar-group + .sidebar-group').styles(
            margin: Margin.only(top: 1.rem),
            padding: Padding.only(top: 1.rem),
            border: Border.only(
              top: BorderSide(
                width: 1.px,
                color: Color('var(--docs-shell-border)'),
              ),
            ),
          ),
          css('.sidebar .sidebar-group-title').styles(
            fontSize: 0.76.rem,
            fontWeight: FontWeight.w800,
            textTransform: TextTransform.upperCase,
            color: Color('var(--docs-shell-muted)'),
            margin: Margin.only(bottom: 0.45.rem),
            raw: {'letter-spacing': '0.12em'},
          ),
          css('.sidebar a').styles(
            radius: BorderRadius.circular(0.9.rem),
            padding: Padding.symmetric(vertical: 0.72.rem, horizontal: 0.85.rem),
            transition: Transition(
              'background-color, color, transform',
              duration: Duration(milliseconds: 150),
            ),
          ),
          css('.sidebar a:hover').styles(
            backgroundColor: Color('var(--docs-shell-accent-soft)'),
            raw: {'transform': 'translateX(2px)'},
          ),
          css('.sidebar .active').styles(
            backgroundColor: Color('var(--docs-shell-accent-soft)'),
            color: Color('var(--docs-shell-accent)'),
            fontWeight: FontWeight.w700,
          ),
          css.media(MediaQuery.all(maxWidth: 959.px), [
            css('&').styles(
              padding: Padding.only(left: 1.rem, right: 1.rem, bottom: 1.rem),
            ),
            css('.sidebar').styles(
              shadow: BoxShadow.unset,
            ),
            css('.sidebar .sidebar-close').styles(
              position: Position.sticky(top: 0.1.rem),
              raw: {'margin-left': 'auto'},
            ),
          ]),
        ]),
        css('.content-container', [
          css('&').styles(
            padding: Padding.only(top: 1.35.rem, right: 0.25.rem, bottom: 3.rem),
          ),
          css('img').styles(
            maxWidth: 100.percent,
            radius: BorderRadius.circular(1.rem),
          ),
        ]),
        css('.content-header', [
          css('&').styles(
            margin: Margin.only(bottom: 2.rem),
            padding: Padding.only(
              top: 1.75.rem,
              right: 1.8.rem,
              bottom: 1.7.rem,
              left: 1.8.rem,
            ),
            radius: BorderRadius.circular(1.5.rem),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border)'),
            ),
            backgroundColor: Color('var(--docs-shell-surface)'),
            shadow: BoxShadow(
              offsetX: Unit.zero,
              offsetY: 28.px,
              blur: 46.px,
              color: Color('var(--docs-shell-shadow)'),
            ),
            raw: {
              'position': 'relative',
              'overflow': 'hidden',
            },
          ),
          css('&:empty').styles(display: Display.none),
          css('&::after').styles(
            raw: {
              'content': '""',
              'position': 'absolute',
              'inset': '0 auto auto 0',
              'width': '8rem',
              'height': '0.35rem',
              'background': 'linear-gradient(90deg, var(--docs-shell-accent), transparent)',
            },
          ),
          css('h1').styles(
            margin: Margin.only(bottom: 0.8.rem),
            fontWeight: FontWeight.w800,
            raw: {
              'letter-spacing': '-0.05em',
              'font-size': 'clamp(2.4rem, 4.8vw, 4rem)',
              'line-height': '0.96',
            },
          ),
          css('p').styles(
            maxWidth: 46.rem,
            fontSize: 1.08.rem,
            color: Color('var(--docs-shell-muted)'),
            raw: {'line-height': '1.75'},
          ),
          css.media(MediaQuery.all(maxWidth: 767.px), [
            css('&').styles(
              margin: Margin.only(bottom: 1.35.rem),
              padding: Padding.only(
                top: 1.1.rem,
                right: 1.rem,
                bottom: 1.rem,
                left: 1.rem,
              ),
              radius: BorderRadius.circular(1.1.rem),
            ),
            css('h1').styles(
              raw: {
                'font-size': 'clamp(1.8rem, 9vw, 2.45rem)',
                'line-height': '1.02',
              },
            ),
            css('p').styles(
              fontSize: 1.rem,
              raw: {'line-height': '1.62'},
            ),
          ]),
        ]),
        css('.api-breadcrumb').styles(
          margin: Margin.only(bottom: 1.2.rem),
          padding: Padding.only(top: 0.25.rem, bottom: 0.15.rem),
        ),
        css('.header-search-shell', [
          css('&').styles(
            maxWidth: 96.rem,
            raw: {
              'margin-left': 'auto',
              'margin-right': 'auto',
            },
          ),
          css('.search-launcher').styles(
            minWidth: 14.5.rem,
            padding:
                Padding.symmetric(vertical: 0.76.rem, horizontal: 0.95.rem),
            backgroundColor: Color('var(--docs-shell-surface)'),
            shadow: BoxShadow(
              offsetX: Unit.zero,
              offsetY: 16.px,
              blur: 34.px,
              color: Color('var(--docs-shell-shadow)'),
            ),
            raw: {
              'backdrop-filter': 'blur(14px)',
              '-webkit-backdrop-filter': 'blur(14px)',
            },
          ),
          css('.search-launcher-label').styles(
            fontWeight: FontWeight.w700,
          ),
        ]),
        css('.docs-search-overlay .docs-search-panel').styles(
          radius: BorderRadius.circular(1.25.rem),
          raw: {
            'backdrop-filter': 'blur(18px)',
            '-webkit-backdrop-filter': 'blur(18px)',
          },
        ),
        css('.docs-search-overlay .docs-search-input').styles(
          padding: Padding.symmetric(vertical: 0.95.rem, horizontal: 1.05.rem),
          fontSize: 1.rem,
        ),
        css('.docs-search-overlay .docs-search-result').styles(
          raw: {'align-items': 'flex-start'},
        ),
        css('.docs-search-overlay .docs-search-title').styles(
          raw: {'line-height': '1.3'},
        ),
        css('.docs-search-overlay .docs-search-url').styles(
          raw: {
            'word-break': 'break-word',
          },
        ),
        css('.toc', [
          css('&').styles(
            padding: Padding.only(top: 1.4.rem, bottom: 2.rem),
          ),
          css('> div').styles(
            position: Position.sticky(top: 7.5.rem),
            maxHeight: 84.vh,
            overflow: Overflow.auto,
            padding: Padding.only(top: 1.rem, right: 1.rem, bottom: 1.rem, left: 1.rem),
            radius: BorderRadius.circular(1.1.rem),
            backgroundColor: Color('var(--docs-shell-surface)'),
            border: Border.all(
              width: 1.px,
              color: Color('var(--docs-shell-border)'),
            ),
            shadow: BoxShadow(
              offsetX: Unit.zero,
              offsetY: 24.px,
              blur: 42.px,
              color: Color('var(--docs-shell-shadow)'),
            ),
          ),
          css('h3').styles(
            margin: Margin.only(bottom: 0.9.rem),
            fontSize: 0.8.rem,
            fontWeight: FontWeight.w800,
            textTransform: TextTransform.upperCase,
            color: Color('var(--docs-shell-muted)'),
            raw: {'letter-spacing': '0.12em'},
          ),
          css.media(MediaQuery.all(maxWidth: 959.px), [
            css('&').styles(display: Display.none),
          ]),
        ]),
        css.media(MediaQuery.all(maxWidth: 959.px), [
          css('.code-block button').styles(opacity: 1),
        ]),
        css('.toc .toc-section', [
          css('&').styles(
            padding: Padding.only(top: 0.35.rem, bottom: 0.35.rem),
            border: Border.only(
              bottom: BorderSide(
                width: 1.px,
                color: Color('var(--docs-shell-border)'),
              ),
            ),
          ),
          css('&:last-child').styles(border: Border.unset),
          css('summary').styles(
            padding: Padding.only(bottom: 0.2.rem),
            fontWeight: FontWeight.w600,
          ),
          css('a').styles(
            color: ContentColors.text,
          ),
          css('a:hover').styles(
            color: Color('var(--docs-shell-accent)'),
          ),
        ]),
        css('.content blockquote').styles(
          shadow: BoxShadow(
            offsetX: Unit.zero,
            offsetY: 18.px,
            blur: 36.px,
            color: Color('var(--docs-shell-shadow)'),
          ),
        ),
        css('.content pre').styles(
          radius: BorderRadius.circular(1.rem),
          border: Border.all(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
          shadow: BoxShadow(
            offsetX: Unit.zero,
            offsetY: 22.px,
            blur: 40.px,
            color: Color('var(--docs-shell-shadow)'),
          ),
        ),
        css('.code-block').styles(
          margin: Margin.only(top: 1.rem, bottom: 1.4.rem),
        ),
        css('.code-block button').styles(
          radius: BorderRadius.circular(0.72.rem),
          raw: {
            'box-shadow': '0 12px 26px -18px var(--docs-shell-shadow)',
          },
        ),
        css('.dartpad-wrapper').styles(
          shadow: BoxShadow(
            offsetX: Unit.zero,
            offsetY: 26.px,
            blur: 46.px,
            color: Color('var(--docs-shell-shadow)'),
          ),
        ),
        css('.dartpad-toolbar').styles(
          backgroundColor: Color('var(--docs-shell-surface)'),
        ),
        css('.mermaid-diagram').styles(
          padding: Padding.all(1.rem),
          border: Border.all(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
          radius: BorderRadius.circular(1.rem),
          backgroundColor: Color('var(--docs-shell-surface)'),
          shadow: BoxShadow(
            offsetX: Unit.zero,
            offsetY: 22.px,
            blur: 42.px,
            color: Color('var(--docs-shell-shadow)'),
          ),
        ),
      ];
}
