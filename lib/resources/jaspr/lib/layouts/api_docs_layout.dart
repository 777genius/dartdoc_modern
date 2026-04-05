import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

import '../components/docs_dartpad_runtime.dart';
import '../components/docs_header.dart';
import '../components/docs_nav_link.dart';
import '../components/docs_page_actions_runtime.dart';
import 'docs_header_shell_styles.dart';
import 'docs_search_styles.dart';
import '../theme/docs_responsive.dart';

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
    yield script(src: 'docs_mermaid_runtime.js?v=5', defer: true);
    yield script(src: 'docs_lightbox_runtime.js?v=3', defer: true);
  }

  @override
  Component buildBody(Page page, Component child) {
    final pageData = page.data.page;
    final pagePath = page.path.replaceAll('\\', '/');
    final isApiPage = pagePath.startsWith('api/');
    final headerComponent = switch (this.header) {
      DocsHeader(
        :final logo,
        :final title,
        :final homeHref,
        :final jasprDocsUrl,
        :final navItems,
        :final items,
        :final vitePressDocsUrl,
      ) =>
        DocsHeader(
          logo: logo,
          title: title,
          homeHref: homeHref,
          currentRoute: page.url,
          jasprDocsUrl: jasprDocsUrl,
          navItems: navItems,
          items: items,
          vitePressDocsUrl: vitePressDocsUrl,
        ),
      final Component component? => component,
      _ => null,
    };
    final breadcrumb = _buildBreadcrumb(page, pageData);
    final collapsibleOutline = pageData['outlineCollapsible'] == true;
    final pageTitle = pageData['title'] as String?;
    final pageDescription = pageData['description'] as String?;
    final pageImage = pageData['image'] as String?;
    final pageImageAlt = pageData['imageAlt'] as String?;
    final hasContentHeader =
        !isApiPage &&
        ((pageTitle?.isNotEmpty ?? false) ||
            (pageDescription?.isNotEmpty ?? false) ||
            (pageImage?.isNotEmpty ?? false));

    return Component.fragment([
      Document.head(
        children: [
          Style(styles: _styles),
          script(src: 'docs_mermaid_runtime.js?v=5', defer: true),
          script(src: 'docs_lightbox_runtime.js?v=3', defer: true),
        ],
      ),
      div(
        classes: 'docs',
        attributes: {'data-docs-layout': 'docs'},
        [
          const DocsDartPadRuntime(),
          const DocsPageActionsRuntime(),
          if (headerComponent case final Component header)
            div(
              classes: 'header-container',
              attributes: {if (this.sidebar != null) 'data-has-sidebar': ''},
              [header],
            ),
          div(classes: 'main-container', [
            div(
              classes: 'sidebar-barrier',
              attributes: {
                'role': 'button',
                'data-docs-sidebar-barrier': 'true',
              },
              [],
            ),
            if (this.sidebar case final Component sidebar)
              div(classes: 'sidebar-container', [sidebar]),
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
                if (page.data['toc'] case final TableOfContents toc
                    when _hasVisibleTocEntries(toc.entries))
                  aside(classes: 'toc', [
                    div([
                      h3([Component.text('On this page')]),
                      _buildToc(toc, page.url, collapsibleOutline),
                    ]),
                  ]),
              ]),
            ]),
          ]),
        ],
      ),
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
      final libraryName =
          (pageData['library'] as String?) ??
          (segments.length == 3 ? pageTitle : libraryDir);
      final isLibraryOverview =
          segments.length == 3 &&
          (segments.last == 'library.md' || segments.last == 'index.md');

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
            to: '/api/$libraryDir/library',
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
          to: '/guide',
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
          button(
            type: ButtonType.button,
            classes: 'action-btn icon-action-btn action-btn-copy',
            attributes: {
              'data-docs-copy-link': 'true',
              'aria-label': 'Copy page link',
              'title': 'Copy page link',
            },
            [span(classes: 'action-btn-icon action-btn-icon-copy', const [])],
          ),
          DocsNavLink(
            to: sourceUrl,
            target: Target.blank,
            attributes: {
              'rel': 'noopener',
              'aria-label': 'Open source',
              'title': 'Open source',
            },
            classes: 'action-btn icon-action-btn action-btn-source',
            children: [
              span(classes: 'action-btn-icon action-btn-icon-source', const []),
            ],
          ),
        ]),
    ]);
  }

  bool _hasVisibleTocEntries(Iterable<TocEntry> entries) {
    for (final entry in entries) {
      if (entry.text.trim().isNotEmpty ||
          _hasVisibleTocEntries(entry.children)) {
        return true;
      }
    }
    return false;
  }

  Component _buildToc(TableOfContents toc, String baseUrl, bool collapsible) {
    if (!collapsible) {
      return ul([
        for (final entry in toc.entries) ..._buildFlatToc(entry, baseUrl),
      ]);
    }

    return ul([
      for (final entry in toc.entries) ..._buildCollapsibleToc(entry, baseUrl),
    ]);
  }

  Iterable<Component> _buildFlatToc(TocEntry entry, String baseUrl) sync* {
    final label = entry.text.trim();
    final anchorId = entry.id.trim();
    final children = [
      for (final child in entry.children) ..._buildFlatToc(child, baseUrl),
    ];

    if (label.isEmpty || anchorId.isEmpty) {
      yield* children;
      return;
    }

    yield li([
      DocsNavLink(
        to: '$baseUrl#$anchorId',
        classes: 'toc-link',
        attributes: {'data-toc-link': anchorId},
        children: [Component.text(label)],
      ),
      if (children.isNotEmpty) ul(children),
    ]);
  }

  Iterable<Component> _buildCollapsibleToc(
    TocEntry entry,
    String baseUrl,
  ) sync* {
    final label = entry.text.trim();
    final anchorId = entry.id.trim();
    final children = [
      for (final child in entry.children)
        ..._buildCollapsibleToc(child, baseUrl),
    ];

    if (label.isEmpty || anchorId.isEmpty) {
      yield* children;
      return;
    }

    if (children.isEmpty) {
      yield li([
        DocsNavLink(
          to: '$baseUrl#$anchorId',
          classes: 'toc-link',
          attributes: {'data-toc-link': anchorId},
          children: [Component.text(label)],
        ),
      ]);
      return;
    }

    yield li([
      details(classes: 'toc-section', [
        summary(classes: 'toc-summary', [
          span(
            classes: 'outline-section-toggle toc-summary-chevron',
            attributes: {'aria-hidden': 'true'},
            [Component.text('▸')],
          ),
          DocsNavLink(
            to: '$baseUrl#$anchorId',
            classes: 'toc-link',
            attributes: {'data-toc-link': anchorId},
            children: [Component.text(label)],
          ),
        ]),
        ul(children),
      ]),
    ]);
  }

  Component _separator() =>
      span(classes: 'breadcrumb-separator', [Component.text('›')]);

  static List<StyleRule> get _styles => [
    ...docsResponsiveRootStyles(),
    ...docsHeaderShellStyles(),
    css(
      '[data-docs-nav-loading] body, [data-docs-nav-loading] .main-container',
    ).styles(raw: {'cursor': 'progress'}),
    css('body.search-open').styles(raw: {'overflow': 'hidden'}),
    css(
      'body.search-open::before',
    ).styles(raw: {'content': 'none', 'display': 'none'}),
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
        fontWeight: FontWeight.w600,
      ),
      css('.breadcrumb-link:hover').styles(
        textDecoration: TextDecoration(line: TextDecorationLine.underline),
      ),
      css(
        '.breadcrumb-separator',
      ).styles(opacity: 0.6, margin: Margin.symmetric(horizontal: 0.5.rem)),
      css('.breadcrumb-category').styles(opacity: 0.85),
      css('.breadcrumb-current').styles(fontWeight: FontWeight.w600),
      css('.breadcrumb-actions').styles(
        display: Display.flex,
        alignItems: AlignItems.center,
        gap: Gap.column(0.55.rem),
      ),
      css('.action-btn').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        gap: Gap.column(0.55.rem),
        padding: Padding.symmetric(vertical: 0.45.rem, horizontal: 0.75.rem),
        radius: BorderRadius.circular(0.8.rem),
        color: Color('var(--docs-shell-muted)'),
        textDecoration: TextDecoration.none,
        fontWeight: FontWeight.w600,
        backgroundColor: Color('var(--docs-shell-surface)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        transition: Transition(
          'background-color, border-color, transform, box-shadow',
          duration: Duration(milliseconds: 150),
        ),
        shadow: BoxShadow(
          offsetX: Unit.zero,
          offsetY: 10.px,
          blur: 20.px,
          color: Color('var(--docs-shell-shadow)'),
        ),
        raw: {'line-height': '1'},
      ),
      css('.icon-action-btn').styles(
        justifyContent: JustifyContent.center,
        width: 1.55.rem,
        height: 1.55.rem,
        padding: Padding.zero,
      ),
      css('.action-btn:hover').styles(
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        color: Color('var(--docs-shell-accent)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        raw: {'transform': 'translateY(-1px)'},
      ),
      css('.action-btn-copy[data-copy-state="copied"]').styles(
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        color: Color('var(--docs-shell-accent)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
      ),
      css('.action-btn-icon').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        width: 0.65.rem,
        minWidth: 0.65.rem,
        height: 0.65.rem,
        color: Color('currentColor'),
        raw: {'line-height': '1'},
      ),
      css('.action-btn-icon-copy').styles(
        position: Position.relative(),
        backgroundColor: Color('transparent'),
        border: Border.unset,
      ),
      css('.action-btn-icon-copy::before, .action-btn-icon-copy::after').styles(
        position: Position.absolute(),
        width: 0.36.rem,
        height: 0.36.rem,
        radius: BorderRadius.circular(0.08.rem),
        border: Border.all(width: 1.px, color: Color('currentColor')),
        backgroundColor: Color('transparent'),
        raw: {'content': '""', 'box-sizing': 'border-box'},
      ),
      css(
        '.action-btn-icon-copy::before',
      ).styles(raw: {'transform': 'translate(-0.07rem, -0.07rem)'}),
      css(
        '.action-btn-icon-copy::after',
      ).styles(raw: {'transform': 'translate(0.07rem, 0.07rem)'}),
      css('.action-btn-icon-source').styles(
        position: Position.relative(),
        backgroundColor: Color('transparent'),
        border: Border.unset,
      ),
      css(
        '.action-btn-icon-source::before, .action-btn-icon-source::after',
      ).styles(
        position: Position.absolute(),
        width: 0.25.rem,
        height: 0.25.rem,
        border: Border.all(width: 1.px, color: Color('currentColor')),
        backgroundColor: Color('transparent'),
        raw: {
          'content': '""',
          'box-sizing': 'border-box',
          'top': '50%',
          'border-right': '0',
          'border-top': '0',
          'transform-origin': 'center',
        },
      ),
      css('.action-btn-icon-source::before').styles(
        raw: {'left': '0.05rem', 'transform': 'translateY(-50%) rotate(45deg)'},
      ),
      css('.action-btn-icon-source::after').styles(
        raw: {
          'right': '0.05rem',
          'transform': 'translateY(-50%) rotate(-135deg)',
        },
      ),
      css('.action-btn-label').styles(fontWeight: FontWeight.w700),
      downCompact([
        css('.icon-action-btn').styles(width: 1.425.rem, height: 1.425.rem),
      ]),
    ]),
    ...docsSearchStyles(),
    css('.toc .toc-section', [
      css('&').styles(margin: Margin.only(bottom: 0.5.rem)),
      css('summary').styles(cursor: Cursor.pointer),
      css('summary a').styles(textDecoration: TextDecoration.none),
      css('ul').styles(
        margin: Margin.only(top: 0.35.rem, left: 0.75.rem),
      ),
    ]),
    css('.content details', [
      css('&').styles(
        margin: Margin.only(top: 1.rem, bottom: 1.1.rem),
        radius: BorderRadius.circular(1.rem),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        backgroundColor: Color('var(--docs-shell-surface)'),
        shadow: BoxShadow(
          offsetX: Unit.zero,
          offsetY: 16.px,
          blur: 28.px,
          color: Color('var(--docs-shell-shadow)'),
        ),
        overflow: Overflow.hidden,
      ),
      css('&[open]').styles(
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
      ),
      css('summary').styles(
        display: Display.flex,
        alignItems: AlignItems.center,
        gap: Gap.column(0.7.rem),
        padding: Padding.symmetric(vertical: 0.9.rem, horizontal: 1.rem),
        fontWeight: FontWeight.w700,
        cursor: Cursor.pointer,
        listStyle: ListStyle.none,
        transition: Transition(
          'background-color, color',
          duration: Duration(milliseconds: 160),
        ),
        raw: {'user-select': 'none'},
      ),
      css('summary::-webkit-details-marker').styles(display: Display.none),
      css('summary::before').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        width: 1.4.rem,
        height: 1.4.rem,
        radius: BorderRadius.circular(999.px),
        color: Color('var(--docs-shell-muted)'),
        backgroundColor: Color('var(--docs-shell-surface-soft)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        transition: Transition(
          'transform, color, background-color, border-color',
          duration: Duration(milliseconds: 180),
        ),
        raw: {
          'content': "'▸'",
          'font-size': '0.74rem',
          'line-height': '1',
          'flex': '0 0 auto',
        },
      ),
      css('summary:hover').styles(
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        color: Color('var(--docs-shell-accent-strong)'),
      ),
      css('summary:focus-visible').styles(
        raw: {
          'outline': '2px solid var(--docs-shell-focus)',
          'outline-offset': '-2px',
        },
      ),
      css('&[open] > summary').styles(
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        color: Color('var(--docs-shell-accent)'),
        border: Border.only(
          bottom: BorderSide(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
        ),
      ),
      css('&[open] > summary::before').styles(
        color: Color('var(--docs-shell-accent)'),
        backgroundColor: Color('var(--docs-shell-surface)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        raw: {'transform': 'rotate(90deg)'},
      ),
      css('& > pre').styles(
        margin: Margin.only(
          top: 0.85.rem,
          right: 0.85.rem,
          bottom: 0.85.rem,
          left: 0.85.rem,
        ),
      ),
      css('& > p, & > div, & > ul, & > ol').styles(
        margin: Margin.only(
          top: 0.85.rem,
          right: 1.rem,
          bottom: 0.85.rem,
          left: 1.rem,
        ),
      ),
    ]),
    css('.content details.docs-disclosure', [
      css('.docs-disclosure-body').styles(
        overflow: Overflow.hidden,
        raw: {
          'height': '0',
          'opacity': '0',
          'transition':
              'height 220ms cubic-bezier(.22, 1, .36, 1), opacity 180ms ease',
          'will-change': 'height, opacity',
        },
      ),
      css('.docs-disclosure-inner').styles(
        raw: {
          'transform': 'translateY(-0.18rem)',
          'opacity': '0',
          'transition':
              'transform 220ms cubic-bezier(.22, 1, .36, 1), opacity 180ms ease',
        },
      ),
      css(
        '&[open] .docs-disclosure-inner, &.is-opening .docs-disclosure-inner',
      ).styles(raw: {'transform': 'translateY(0)', 'opacity': '1'}),
      css(
        '&.is-closing .docs-disclosure-inner',
      ).styles(raw: {'transform': 'translateY(-0.12rem)', 'opacity': '0'}),
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
      css('p').styles(
        margin: Margin.only(top: 0.35.rem, bottom: 0.35.rem),
      ),
      css('p:first-of-type').styles(margin: Margin.only(top: Unit.zero)),
      css('p:last-of-type').styles(margin: Margin.only(bottom: Unit.zero)),
      css('strong').styles(fontWeight: FontWeight.w700),
    ]),
    css('.code-block', [
      css(
        '&',
      ).styles(position: Position.relative(), raw: {'isolation': 'isolate'}),
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
        zIndex: ZIndex(1),
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
        padding: Padding.all(0.65.rem),
        border: Border.only(
          top: BorderSide(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
        ),
      ),
      css('.dartpad-toolbar > *').styles(raw: {'flex': '0 0 auto'}),
      css('.dartpad-btn').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        gap: Gap.column(0.32.rem),
        minHeight: 2.2.rem,
        padding: Padding.symmetric(vertical: 0.28.rem, horizontal: 0.68.rem),
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        color: ContentColors.text,
        radius: BorderRadius.circular(0.72.rem),
        textDecoration: TextDecoration.none,
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        cursor: Cursor.pointer,
        fontWeight: FontWeight.w700,
        fontSize: 0.92.rem,
        raw: {'line-height': '1'},
      ),
      css('.dartpad-btn-icon').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        minWidth: 0.95.rem,
        fontSize: 0.78.rem,
        fontWeight: FontWeight.w800,
        color: Color('var(--docs-shell-accent)'),
      ),
      css('.dartpad-btn-label').styles(fontWeight: FontWeight.w700),
      css('.dartpad-btn:hover').styles(
        backgroundColor: Color('var(--docs-shell-surface)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
      ),
      css('.dartpad-run, .dartpad-copy').styles(
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        color: Color('var(--docs-shell-accent-strong)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
      ),
      css(
        '.dartpad-run .dartpad-btn-icon, .dartpad-copy .dartpad-btn-icon',
      ).styles(color: Color('var(--docs-shell-accent-strong)')),
      css('.dartpad-open').styles(
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        color: ContentColors.text,
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
      ),
      css(
        '.dartpad-stage',
      ).styles(backgroundColor: Color('var(--docs-shell-dartpad-stage)')),
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
      css(
        '.mermaid-frame',
      ).styles(display: Display.grid, gap: Gap.row(0.9.rem)),
      css(
        '.content img[data-docs-lightbox-image], .mermaid-frame[data-docs-lightbox-mermaid]',
      ).styles(cursor: Cursor.zoomIn),
      css('.mermaid-placeholder').styles(
        display: Display.flex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        padding: Padding.symmetric(vertical: 1.2.rem, horizontal: 1.rem),
        radius: BorderRadius.circular(0.85.rem),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        backgroundColor: Color('var(--docs-shell-surface-soft)'),
      ),
      css('.mermaid-placeholder-inner').styles(
        display: Display.grid,
        justifyItems: JustifyItems.center,
        gap: Gap.row(0.55.rem),
        raw: {'text-align': 'center', 'max-width': '32rem'},
      ),
      css('.mermaid-placeholder-badge').styles(
        padding: Padding.symmetric(vertical: 0.22.rem, horizontal: 0.55.rem),
        radius: BorderRadius.circular(999.px),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        color: Color('var(--docs-shell-accent-strong)'),
        fontWeight: FontWeight.w700,
        fontSize: 0.76.rem,
        textTransform: TextTransform.upperCase,
        raw: {'letter-spacing': '0.08em'},
      ),
      css(
        '.mermaid-placeholder[hidden], .mermaid-host[hidden], .mermaid-fallback[hidden]',
      ).styles(display: Display.none, raw: {'display': 'none !important'}),
      css('.mermaid-placeholder-label').styles(
        color: Color('var(--docs-shell-muted-text)'),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.01.rem,
      ),
      css('.mermaid-placeholder-hint').styles(
        margin: Margin.zero,
        color: Color('var(--docs-shell-muted)'),
        fontSize: 0.92.rem,
        raw: {'line-height': '1.55'},
      ),
      css('.mermaid-host').styles(
        display: Display.block,
        overflow: Overflow.auto,
        raw: {'opacity': '0', 'transition': 'opacity 180ms ease'},
      ),
      css('.mermaid-host svg').styles(
        maxWidth: 100.percent,
        display: Display.block,
        raw: {'margin-left': 'auto', 'margin-right': 'auto'},
      ),
      css(
        '.mermaid-fallback',
      ).styles(display: Display.grid, gap: Gap.row(0.75.rem)),
      css('.mermaid-fallback-message').styles(
        color: Color('var(--docs-shell-muted-text)'),
        fontSize: 0.95.rem,
        raw: {'line-height': '1.5'},
      ),
    ]),
    css('.docs', [
      css('&').styles(
        backgroundColor: ContentColors.background,
        raw: {
          'overflow': 'visible',
          'background-image':
              'radial-gradient(circle at top left, var(--docs-shell-accent-soft) 0, transparent 30rem), radial-gradient(circle at top right, var(--docs-shell-accent-soft) 0, transparent 24rem)',
        },
      ),
      css('.main-container').styles(
        maxWidth: 100.percent,
        margin: Margin.zero,
        raw: {'overflow': 'visible'},
      ),
      css('main').styles(width: 100.percent, raw: {'overflow': 'visible'}),
      css('.main-container main').styles(
        padding: Padding.only(top: Unit.zero),
      ),
      css('main > div').styles(
        display: Display.grid,
        raw: {
          'overflow': 'visible',
          'grid-template-columns': 'minmax(0, 1fr) var(--docs-shell-toc-width)',
          'gap': 'var(--docs-shell-grid-gap)',
          'max-width': 'var(--docs-shell-main-max-width)',
          'margin': '0 auto',
          'padding':
              'var(--docs-shell-main-pad-top) var(--docs-shell-main-pad-inline) var(--docs-shell-main-pad-bottom)',
        },
      ),
      css('.main-container main > div').styles(
        raw: {
          'padding-top': '0.75rem',
          'padding-left': '2.5rem !important',
          'padding-right': '0 !important',
          'gap': '2.5rem !important',
        },
      ),
      downWide([
        css('main > div').styles(
          raw: {
            'grid-template-columns':
                'minmax(0, 1fr) var(--docs-shell-toc-width)',
          },
        ),
      ]),
      downContent([
        css('main > div').styles(
          display: Display.block,
          raw: {
            'overflow-x': 'clip',
            'padding':
                'var(--docs-shell-main-pad-top) var(--docs-shell-main-pad-inline) var(--docs-shell-main-pad-bottom)',
          },
        ),
      ]),
    ]),
    css('.docs .main-container .sidebar-container').styles(
      raw: {
        'top': 'var(--docs-shell-sticky-top)',
        'width': 'var(--docs-shell-sidebar-width)',
      },
    ),
    css('.sidebar-container', [
      css('&').styles(
        alignSelf: AlignSelf.start,
        padding: Padding.only(
          top: 0.95.rem,
          left: 0.7.rem,
          right: 0.7.rem,
          bottom: 2.25.rem,
        ),
        raw: {'overflow': 'visible'},
      ),
      css('.sidebar').styles(
        position: Position.sticky(top: Unit.zero),
        maxHeight: 84.vh,
        overflow: Overflow.visible,
        padding: Padding.zero,
        radius: BorderRadius.circular(Unit.zero),
        backgroundColor: Color('transparent'),
        border: Border.unset,
        shadow: BoxShadow.unset,
        raw: {'top': 'var(--docs-shell-sticky-top)'},
      ),
      css('.sidebar > div').styles(
        maxHeight: 84.vh,
        overflow: Overflow.auto,
        padding: Padding.only(
          top: Unit.zero,
          right: 0.7.rem,
          bottom: 0.35.rem,
          left: 0.35.rem,
        ),
        radius: BorderRadius.circular(Unit.zero),
      ),
      css('.sidebar .sidebar-group:first-child').styles(
        padding: Padding.only(top: Unit.zero, right: 0.2.rem),
      ),
      css('.sidebar .sidebar-group + .sidebar-group').styles(
        margin: Margin.only(top: 1.05.rem),
        padding: Padding.only(top: 1.05.rem),
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
        radius: BorderRadius.circular(Unit.zero),
        padding: Padding.symmetric(vertical: 0.5.rem, horizontal: Unit.zero),
        transition: Transition(
          'color, opacity',
          duration: Duration(milliseconds: 150),
        ),
      ),
      css('.sidebar a:hover').styles(backgroundColor: Color('transparent')),
      css('.sidebar .active').styles(
        backgroundColor: Color('transparent'),
        color: Color('var(--docs-shell-accent)'),
        fontWeight: FontWeight.w700,
      ),
      downContent([
        css('.sidebar').styles(
          position: Position.relative(),
          height: 100.percent,
          maxHeight: 100.percent,
          radius: BorderRadius.circular(Unit.zero),
          border: Border.only(
            right: BorderSide(
              width: 1.px,
              color: Color('var(--docs-shell-border)'),
            ),
          ),
          backgroundColor: Color('var(--docs-shell-surface-elevated)'),
          shadow: BoxShadow(
            offsetX: 8.px,
            offsetY: Unit.zero,
            blur: 40.px,
            color: Color('var(--docs-shell-shadow)'),
          ),
          overflow: Overflow.hidden,
          padding: Padding.zero,
          display: Display.flex,
          flexDirection: FlexDirection.column,
          raw: {'border-radius': '0', 'top': 'auto'},
        ),
        css('.sidebar > div').styles(
          maxHeight: 100.percent,
          overflow: Overflow.auto,
          padding: Padding.only(
            top: Unit.zero,
            right: 0.6.rem,
            bottom: 1.rem,
            left: 2.5.rem,
          ),
          raw: {'flex': '1 1 auto'},
        ),
        css('.sidebar .sidebar-close').styles(
          position: Position.absolute(top: 0.6.rem, right: 0.6.rem),
          border: Border.none,
          backgroundColor: Color('transparent'),
          zIndex: ZIndex(1),
          raw: {'margin-left': 'auto'},
        ),
      ]),
    ]),
    downContent([
      css('.docs .main-container .sidebar-container').styles(
        position: Position.fixed(left: Unit.zero),
        zIndex: ZIndex(55),
        padding: Padding.zero,
        display: Display.flex,
        flexDirection: FlexDirection.column,
        raw: {
          'top': 'calc(var(--docs-shell-header-height) + 0.5rem)',
          'height': 'calc(100vh - var(--docs-shell-header-height) - 0.5rem)',
          'width': 'min(var(--docs-shell-drawer-width), 85vw)',
          'transform': 'translateX(-100%)',
          'opacity': '0',
          'pointer-events': 'none',
          'transition': 'transform 220ms ease, opacity 180ms ease',
        },
      ),
      css('.docs .main-container .sidebar-container.open').styles(
        raw: {
          'transform': 'translateX(0)',
          'opacity': '1',
          'pointer-events': 'auto',
        },
      ),
    ]),
    css('.docs .main-container .sidebar-barrier').styles(display: Display.none),
    downContent([
      css('.docs .main-container .sidebar-barrier').styles(
        display: Display.block,
        position: Position.fixed(
          top: Unit.zero,
          left: Unit.zero,
          right: Unit.zero,
          bottom: Unit.zero,
        ),
        zIndex: ZIndex(54),
        backgroundColor: Color('var(--docs-shell-overlay)'),
        opacity: 0,
        transition: Transition(
          'opacity',
          duration: Duration(milliseconds: 180),
        ),
        raw: {'pointer-events': 'none'},
      ),
      css(
        '.docs .main-container .sidebar-barrier:has(+ .sidebar-container.open)',
      ).styles(opacity: 1, raw: {'pointer-events': 'auto'}),
    ]),
    css('.content-container', [
      css('&').styles(
        padding: Padding.only(top: 1.55.rem, right: Unit.zero, bottom: 3.rem),
        minWidth: Unit.zero,
      ),
      css(
        'img',
      ).styles(maxWidth: 100.percent, radius: BorderRadius.circular(1.rem)),
      downMobile([
        css('&').styles(
          padding: Padding.only(top: 1.15.rem, right: Unit.zero, bottom: 2.rem),
          raw: {
            'padding-top': 'var(--docs-shell-content-pad-top)',
            'padding-right': 'var(--docs-shell-content-pad-right)',
            'padding-bottom': 'var(--docs-shell-content-pad-bottom)',
          },
        ),
      ]),
    ]),
    css('.docs .main-container main > div > .content-container').styles(
      raw: {
        'width': '100%',
        'max-width': 'none !important',
        'padding-right': '0 !important',
        'box-sizing': 'border-box',
      },
    ),
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
          offsetY: 18.px,
          blur: 32.px,
          color: Color('var(--docs-shell-shadow)'),
        ),
        raw: {
          'position': 'relative',
          'overflow': 'hidden',
          'box-sizing': 'border-box',
          'width': '100%',
          'max-width': '100%',
          'padding':
              'var(--docs-shell-content-header-pad-y) var(--docs-shell-content-header-pad-x) calc(var(--docs-shell-content-header-pad-y) - 0.05rem)',
          'border-radius': 'var(--docs-shell-content-header-radius)',
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
          'background':
              'linear-gradient(90deg, var(--docs-shell-accent), transparent)',
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
      downMobile([
        css('&').styles(margin: Margin.only(bottom: 1.35.rem)),
        css('h1').styles(
          raw: {
            'font-size': 'clamp(1.8rem, 9vw, 2.45rem)',
            'line-height': '1.02',
          },
        ),
        css('p').styles(fontSize: 1.rem, raw: {'line-height': '1.62'}),
      ]),
    ]),
    css('.api-breadcrumb').styles(
      margin: Margin.only(bottom: 1.rem),
      padding: Padding.only(top: 0.15.rem, bottom: 0.15.rem),
    ),
    css('.header-search-shell', [
      css('&').styles(maxWidth: Unit.auto),
      css('.search-launcher').styles(
        minWidth: 0.rem,
        padding: Padding.symmetric(vertical: 0.46.rem, horizontal: 0.72.rem),
        backgroundColor: Color('var(--docs-shell-surface)'),
        shadow: BoxShadow(
          offsetX: Unit.zero,
          offsetY: 8.px,
          blur: 16.px,
          color: Color('var(--docs-shell-shadow)'),
        ),
        raw: {
          'min-width': 'var(--docs-shell-search-launcher-min)',
          'backdrop-filter': 'blur(8px)',
          '-webkit-backdrop-filter': 'blur(8px)',
        },
      ),
      css(
        '.search-launcher-label',
      ).styles(fontWeight: FontWeight.w700, fontSize: 0.95.rem),
      downMobile([
        css('.search-launcher').styles(
          minWidth: 0.rem,
          padding: Padding.symmetric(vertical: 0.4.rem, horizontal: 0.6.rem),
        ),
      ]),
      downCompact([
        css('&').styles(raw: {'flex': '0 0 auto'}),
        css('.search-launcher').styles(
          minWidth: 0.rem,
          padding: Padding.symmetric(vertical: 0.36.rem, horizontal: 0.48.rem),
          raw: {'max-width': '7rem'},
        ),
        css('.search-launcher-label').styles(fontSize: 0.82.rem),
      ]),
    ]),
    css('.docs-search-overlay .docs-search-panel').styles(
      radius: BorderRadius.circular(1.25.rem),
      raw: {
        'backdrop-filter': 'blur(18px)',
        '-webkit-backdrop-filter': 'blur(18px)',
        'max-width': 'var(--docs-shell-search-panel-width)',
      },
    ),
    css('.docs-search-overlay .docs-search-input').styles(
      padding: Padding.symmetric(vertical: 0.95.rem, horizontal: 1.05.rem),
      fontSize: 1.rem,
    ),
    css(
      '.docs-search-overlay .docs-search-result',
    ).styles(raw: {'align-items': 'flex-start'}),
    css(
      '.docs-search-overlay .docs-search-title',
    ).styles(raw: {'line-height': '1.3'}),
    css(
      '.docs-search-overlay .docs-search-url',
    ).styles(raw: {'word-break': 'break-word'}),
    css('.toc', [
      css('&').styles(
        padding: Padding.only(top: 0.05.rem, right: Unit.zero, bottom: 1.2.rem),
      ),
      css('ul').styles(
        listStyle: ListStyle.none,
        margin: Margin.zero,
        padding: Padding.zero,
      ),
      css('li + li').styles(margin: Margin.only(top: 0.08.rem)),
      css('> div').styles(
        position: Position.sticky(top: Unit.zero),
        maxHeight: 80.vh,
        overflow: Overflow.auto,
        padding: Padding.only(left: 0.45.rem),
        raw: {
          'top': 'var(--docs-shell-sticky-top)',
          'overscroll-behavior': 'contain',
          'border-left': '1px solid var(--docs-shell-border)',
          'box-sizing': 'border-box',
        },
      ),
      css('h3').styles(
        margin: Margin.only(bottom: 0.28.rem),
        fontSize: 0.72.rem,
        fontWeight: FontWeight.w800,
        textTransform: TextTransform.upperCase,
        color: Color('var(--docs-shell-muted)'),
        raw: {'letter-spacing': '0.12em'},
      ),
      css('.toc-link').styles(
        display: Display.block,
        padding: Padding.only(
          top: 0.09.rem,
          right: Unit.zero,
          bottom: 0.09.rem,
          left: 0.42.rem,
        ),
        radius: BorderRadius.circular(Unit.zero),
        color: ContentColors.text,
        textDecoration: TextDecoration.none,
        fontSize: 0.85.rem,
        transition: Transition(
          'color, opacity',
          duration: Duration(milliseconds: 150),
        ),
        raw: {
          'line-height': '1.16',
          'position': 'relative',
          'z-index': '1',
          'text-wrap': 'pretty',
        },
      ),
      css('.toc-link::before').styles(
        position: Position.absolute(),
        radius: BorderRadius.circular(999.px),
        opacity: 0,
        raw: {
          'content': "''",
          'top': '0.18rem',
          'bottom': '0.18rem',
          'left': '-0.34rem',
          'width': '3px',
          'pointer-events': 'none',
          'background': 'var(--docs-shell-accent)',
          'box-shadow':
              '0 0 0 1px color-mix(in srgb, var(--docs-shell-accent) 18%, transparent)',
          'transition': 'opacity 120ms ease',
        },
      ),
      css('.toc-link:hover').styles(
        color: Color('var(--docs-shell-accent-strong)'),
        raw: {'opacity': '1'},
      ),
      css('.toc-link:focus-visible').styles(
        radius: BorderRadius.circular(0.45.rem),
        raw: {
          'outline': '2px solid var(--docs-shell-accent)',
          'outline-offset': '2px',
        },
      ),
      css('.toc-link:visited').styles(color: ContentColors.text),
      css('.toc-link.active').styles(
        color: Color('var(--docs-shell-accent)'),
        fontWeight: FontWeight.w600,
        raw: {'opacity': '1'},
      ),
      css('.toc-link.active::before').styles(opacity: 1),
      css('ul ul').styles(
        margin: Margin.only(top: 0.01.rem),
        padding: Padding.only(left: 1.rem),
        border: Border.unset,
      ),
      css('ul ul ul').styles(padding: Padding.only(left: 0.78.rem)),
      css('ul ul ul ul').styles(padding: Padding.only(left: 0.78.rem)),
      css('ul ul > li').styles(raw: {'margin-left': '0'}),
      css('ul ul ul > li').styles(raw: {'margin-left': '0'}),
      css('ul ul ul ul > li').styles(raw: {'margin-left': '0'}),
      css(
        'ul ul .toc-link',
      ).styles(fontSize: 0.8.rem, color: Color('var(--docs-shell-muted)')),
      css(
        'ul ul .toc-link:visited',
      ).styles(color: Color('var(--docs-shell-muted)')),
      css(
        'ul ul .toc-link.active',
      ).styles(color: Color('var(--docs-shell-accent)')),
      downContent([css('&').styles(display: Display.none)]),
    ]),
    css('.docs .main-container main > div > aside.toc').styles(
      raw: {
        'width': 'var(--docs-shell-toc-width) !important',
        'max-width': 'var(--docs-shell-toc-width) !important',
        'min-width': '0',
        'justify-self': 'end',
      },
    ),
    downContent([css('.code-block button').styles(opacity: 1)]),
    css('.toc .toc-section', [
      css('&').styles(
        padding: Padding.only(top: 0.02.rem, bottom: 0.02.rem),
        border: Border.unset,
      ),
      css('> summary').styles(display: Display.block),
      css('summary').styles(
        padding: Padding.zero,
        fontWeight: FontWeight.w500,
        listStyle: ListStyle.none,
        cursor: Cursor.pointer,
      ),
      css('summary::-webkit-details-marker').styles(display: Display.none),
      css('.toc-summary').styles(
        display: Display.flex,
        alignItems: AlignItems.baseline,
        gap: Gap.column(0.1.rem),
        padding: Padding.zero,
        raw: {'width': '100%'},
      ),
      css('.outline-section-toggle').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        width: 0.875.rem,
        color: Color('var(--docs-shell-muted)'),
        transition: Transition(
          'transform, color',
          duration: Duration(milliseconds: 150),
        ),
        raw: {
          'flex': '0 0 auto',
          'font-size': '11px',
          'line-height': '1',
          'user-select': 'none',
        },
      ),
      css(
        'summary:hover .outline-section-toggle',
      ).styles(color: Color('var(--docs-shell-accent)')),
      css('&[open] .toc-summary-chevron').styles(
        color: Color('var(--docs-shell-accent)'),
        raw: {'transform': 'rotate(90deg)'},
      ),
      css('> ul').styles(raw: {'width': '100%'}),
      css('.toc-summary .toc-link').styles(
        padding: Padding.only(
          top: 0.09.rem,
          right: Unit.zero,
          bottom: 0.09.rem,
          left: 0.08.rem,
        ),
        raw: {'flex': '1 1 auto'},
      ),
      css('a').styles(color: ContentColors.text),
      css('a:hover').styles(color: Color('var(--docs-shell-accent)')),
    ]),
    css('.content blockquote').styles(
      shadow: BoxShadow(
        offsetX: Unit.zero,
        offsetY: 18.px,
        blur: 36.px,
        color: Color('var(--docs-shell-shadow)'),
      ),
    ),
    css('.content p, .content li').styles(
      fontSize: 1.01.rem,
      raw: {'line-height': '1.74', 'text-wrap': 'pretty'},
    ),
    css('.content a').styles(
      color: Color('var(--docs-shell-accent)'),
      textDecoration: TextDecoration.none,
      fontWeight: FontWeight.w600,
      raw: {
        'text-decoration-thickness': '0.08em',
        'text-underline-offset': '0.16em',
      },
    ),
    css('.content a:hover').styles(
      textDecoration: TextDecoration(line: TextDecorationLine.underline),
    ),
    css('.content .member-signature a.type-link').styles(
      fontWeight: FontWeight.w400,
      raw: {
        'text-decoration': 'underline !important',
        'text-decoration-line': 'underline !important',
        'text-decoration-color': 'currentColor !important',
        'text-decoration-thickness': '1.5px !important',
        'text-underline-offset': '2px',
      },
    ),
    css(
      '.content .member-signature a.type-link:hover',
    ).styles(raw: {'text-decoration-thickness': '2px !important'}),
    css(
      '.content ul, .content ol',
    ).styles(padding: Padding.only(left: 1.18.rem)),
    css('.content li + li').styles(margin: Margin.only(top: 0.22.rem)),
    css('.content h2').styles(
      margin: Margin.only(top: 2.4.rem, bottom: 0.8.rem),
      raw: {'letter-spacing': '-0.03em'},
    ),
    css('.content h3').styles(
      margin: Margin.only(top: 1.85.rem, bottom: 0.65.rem),
      raw: {'letter-spacing': '-0.02em'},
    ),
    css('.content table', [
      css('&').styles(
        margin: Margin.only(top: 1.35.rem, bottom: 1.75.rem),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        radius: BorderRadius.circular(1.rem),
        backgroundColor: Color('var(--docs-shell-surface)'),
        raw: {
          'border-collapse': 'separate',
          'border-spacing': '0',
          'overflow-x': 'auto',
          'overflow-y': 'hidden',
          'display': 'block',
          'width': 'max-content',
          'min-width': '100%',
          'max-width': '100%',
        },
      ),
      css('thead th').styles(
        padding: Padding.symmetric(vertical: 0.86.rem, horizontal: 1.rem),
        backgroundColor: Color('var(--docs-shell-surface-soft)'),
        border: Border.only(
          bottom: BorderSide(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
        ),
        fontWeight: FontWeight.w700,
        fontSize: 0.92.rem,
        raw: {'white-space': 'nowrap', 'text-align': 'left'},
      ),
      css('tbody td').styles(
        padding: Padding.symmetric(vertical: 0.85.rem, horizontal: 1.rem),
        border: Border.only(
          bottom: BorderSide(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
        ),
        fontSize: 0.96.rem,
        raw: {'vertical-align': 'top'},
      ),
      css('thead th:first-child, tbody td:first-child').styles(
        raw: {'width': '1%', 'min-width': '20rem', 'white-space': 'nowrap'},
      ),
      css('tbody tr:last-child td').styles(border: Border.unset),
      css(
        'tbody tr:hover td',
      ).styles(backgroundColor: Color('var(--docs-shell-accent-soft)')),
      css('th:first-child, td:first-child').styles(fontWeight: FontWeight.w600),
      css(
        'tbody td:first-child, tbody td:first-child a',
      ).styles(raw: {'white-space': 'nowrap', 'overflow-wrap': 'normal'}),
      css('tbody td:last-child').styles(
        color: Color('var(--docs-shell-muted)'),
        raw: {'overflow-wrap': 'break-word'},
      ),
      css('tbody td a').styles(fontWeight: FontWeight.w600),
      downMobile([
        css('&').styles(
          margin: Margin.only(top: 1.1.rem, bottom: 1.45.rem),
          raw: {'min-width': '34rem'},
        ),
        css('thead th').styles(
          padding: Padding.symmetric(vertical: 0.75.rem, horizontal: 0.82.rem),
        ),
        css('tbody td').styles(
          padding: Padding.symmetric(vertical: 0.75.rem, horizontal: 0.82.rem),
        ),
        css(
          'thead th:first-child, tbody td:first-child',
        ).styles(raw: {'width': '1%', 'min-width': '18rem'}),
      ]),
    ]),
    css('.content pre').styles(
      radius: BorderRadius.circular(1.rem),
      border: Border.all(width: 1.px, color: Color('var(--docs-shell-border)')),
      shadow: BoxShadow(
        offsetX: Unit.zero,
        offsetY: 22.px,
        blur: 40.px,
        color: Color('var(--docs-shell-shadow)'),
      ),
    ),
    css('.content pre code.hljs').styles(
      raw: {
        'display': 'block',
        'background': 'transparent',
        'color': 'inherit',
      },
    ),
    css('.content pre .hljs-comment, .content pre .hljs-quote').styles(
      color: Color('var(--docs-shell-muted)'),
      fontStyle: FontStyle.italic,
    ),
    css(
      '.content pre .hljs-keyword, .content pre .hljs-selector-tag, .content pre .hljs-meta, .content pre .hljs-subst',
    ).styles(
      color: Color('var(--docs-shell-accent-strong)'),
      fontWeight: FontWeight.w600,
    ),
    css(
      '.content pre .hljs-built_in, .content pre .hljs-type, .content pre .hljs-title, .content pre .hljs-section, .content pre .hljs-name, .content pre .hljs-tag, .content pre .hljs-attribute, .content pre .hljs-selector-id, .content pre .hljs-selector-class, .content pre .hljs-selector-attr, .content pre .hljs-selector-pseudo, .content pre .function_, .content pre .class_',
    ).styles(
      color: Color('var(--docs-shell-accent)'),
      fontWeight: FontWeight.w500,
    ),
    css(
      '.content pre .hljs-string, .content pre .hljs-regexp, .content pre .hljs-link, .content pre .hljs-symbol, .content pre .hljs-bullet',
    ).styles(
      raw: {
        'color':
            'color-mix(in srgb, var(--docs-shell-accent-strong) 66%, currentColor)',
      },
    ),
    css(
      '.content pre .hljs-number, .content pre .hljs-literal, .content pre .hljs-variable, .content pre .hljs-template-variable, .content pre .hljs-params, .content pre .hljs-attr, .content pre .hljs-operator, .content pre .hljs-punctuation',
    ).styles(
      raw: {
        'color':
            'color-mix(in srgb, currentColor 72%, var(--docs-shell-accent) 28%)',
      },
    ),
    css('.content pre .hljs-addition').styles(
      color: Color('var(--docs-shell-accent-strong)'),
      raw: {
        'background':
            'color-mix(in srgb, var(--docs-shell-accent-soft) 72%, transparent)',
      },
    ),
    css('.content pre .hljs-deletion').styles(
      color: Color('var(--docs-shell-shadow)'),
      raw: {
        'background':
            'color-mix(in srgb, var(--docs-shell-border) 38%, transparent)',
      },
    ),
    css('.content pre .hljs-emphasis').styles(fontStyle: FontStyle.italic),
    css('.content pre .hljs-strong').styles(fontWeight: FontWeight.w700),
    css('.content .member-signature').styles(
      margin: Margin.only(top: 0.32.rem, bottom: 0.72.rem),
    ),
    css('.content .member-signature .member-signature-code').styles(
      radius: BorderRadius.circular(0.8.rem),
      border: Border.all(width: 1.px, color: Color('var(--docs-shell-border)')),
      shadow: BoxShadow(
        offsetX: Unit.zero,
        offsetY: 8.px,
        blur: 18.px,
        color: Color('var(--docs-shell-shadow)'),
      ),
      raw: {
        'white-space': 'pre-wrap',
        'overflow-wrap': 'break-word',
        'font-family': 'var(--content-code-font)',
        'font-size': '0.92rem',
        'line-height': '1.08',
        'padding-top': '0.26rem',
        'padding-bottom': '0.26rem',
      },
    ),
    css(
      '.content .member-signature .member-signature-line',
    ).styles(display: Display.block),
    css('.content .member-signature a').styles(
      fontWeight: FontWeight.w400,
      textDecoration: TextDecoration.none,
      raw: {
        'font-family': 'inherit',
        'font-size': 'inherit',
        'line-height': 'inherit',
        'letter-spacing': 'normal',
        'word-spacing': 'normal',
      },
    ),
    css('.content .member-signature a:hover').styles(
      textDecoration: TextDecoration(line: TextDecorationLine.underline),
      raw: {
        'text-decoration-thickness': '0.08em',
        'text-underline-offset': '0.14em',
      },
    ),
    css('.code-block').styles(
      margin: Margin.only(top: 1.rem, bottom: 1.4.rem),
    ),
    css('.code-block button').styles(
      radius: BorderRadius.circular(0.72.rem),
      raw: {'box-shadow': '0 12px 26px -18px var(--docs-shell-shadow)'},
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
      justifyContent: JustifyContent.spaceBetween,
      flexWrap: FlexWrap.wrap,
    ),
    css('.dartpad-btn').styles(
      fontWeight: FontWeight.w600,
      shadow: BoxShadow(
        offsetX: Unit.zero,
        offsetY: 12.px,
        blur: 22.px,
        color: Color('var(--docs-shell-shadow)'),
      ),
      transition: Transition(
        'background-color, border-color, transform, box-shadow',
        duration: Duration(milliseconds: 150),
      ),
    ),
    css('.dartpad-btn:focus-visible').styles(
      outline: Outline(
        width: OutlineWidth(3.px),
        style: OutlineStyle.solid,
        color: Color('var(--docs-shell-focus)'),
        offset: 2.px,
      ),
    ),
    css('.dartpad-btn:hover').styles(raw: {'transform': 'translateY(-1px)'}),
    css(
      '.dartpad-open:hover',
    ).styles(backgroundColor: Color('var(--docs-shell-surface-soft)')),
    css('.mermaid-diagram').styles(
      padding: Padding.all(1.rem),
      border: Border.all(width: 1.px, color: Color('var(--docs-shell-border)')),
      radius: BorderRadius.circular(1.rem),
      backgroundColor: Color('var(--docs-shell-surface)'),
      shadow: BoxShadow(
        offsetX: Unit.zero,
        offsetY: 22.px,
        blur: 42.px,
        color: Color('var(--docs-shell-shadow)'),
      ),
    ),
    css(
      '.mermaid-diagram[data-mermaid-state="rendered"] .mermaid-host',
    ).styles(display: Display.block, raw: {'opacity': '1'}),
    css(
      '.mermaid-diagram[data-mermaid-state="pending"] .mermaid-placeholder',
    ).styles(
      raw: {
        'background':
            'linear-gradient(135deg, var(--docs-shell-surface-soft), color-mix(in srgb, var(--docs-shell-accent-soft) 38%, var(--docs-shell-surface-soft)))',
        'min-height': '7rem',
      },
    ),
    css(
      '.mermaid-diagram[data-mermaid-state="error"] .mermaid-fallback',
    ).styles(display: Display.grid),
    css(
      '.mermaid-diagram[data-mermaid-state="error"] .mermaid-fallback-message',
    ).styles(
      padding: Padding.symmetric(vertical: 0.75.rem, horizontal: 0.9.rem),
      radius: BorderRadius.circular(0.8.rem),
      backgroundColor: Color('var(--docs-shell-surface-soft)'),
    ),
    css('.mermaid-placeholder-label').styles(raw: {'font-size': '1rem'}),
    css('.mermaid-placeholder-hint').styles(raw: {'max-width': '28rem'}),
    css('.mermaid-fallback-message').styles(raw: {'position': 'relative'}),
    css('.mermaid-fallback-message::before').styles(
      raw: {
        'content': '"Mermaid"',
        'display': 'inline-block',
        'margin-right': '0.55rem',
        'padding': '0.18rem 0.45rem',
        'border-radius': '999px',
        'background': 'var(--docs-shell-accent-soft)',
        'color': 'var(--docs-shell-accent-strong)',
        'font-weight': '700',
        'font-size': '0.75rem',
        'vertical-align': 'middle',
      },
    ),
    css(
      '.content h2[id], .content h3[id], .content h4[id], .content h5[id], .content h6[id]',
    ).styles(raw: {'scroll-margin-top': 'var(--docs-shell-anchor-offset)'}),
    downMobile([
      css(
        '.content p, .content li',
      ).styles(fontSize: 0.98.rem, raw: {'line-height': '1.68'}),
    ]),
  ];
}
