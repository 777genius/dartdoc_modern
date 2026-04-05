import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

import '../components/docs_header.dart';
import '../components/docs_home_hero.dart';
import 'docs_header_shell_styles.dart';
import 'docs_search_styles.dart';
import '../theme/docs_responsive.dart';

class DocsHomeLayout extends PageLayoutBase {
  const DocsHomeLayout({
    required this.packageName,
    required this.primaryActionHref,
    required this.apiHref,
    required this.hasGuideLinks,
    this.jasprDocsUrl,
    this.vitePressDocsUrl,
    this.header,
    this.footer,
  });

  final String packageName;
  final String primaryActionHref;
  final String apiHref;
  final bool hasGuideLinks;
  final String? jasprDocsUrl;
  final String? vitePressDocsUrl;
  final Component? header;
  final Component? footer;

  @override
  String get name => 'home';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    yield* super.buildHead(page);
    yield Style(styles: _styles);
  }

  @override
  Component buildBody(Page page, Component child) {
    final pageData = page.data.page;
    final hero = _resolveHero(pageData);
    final features = _resolveFeatures(pageData['features']);
    final headerComponent = switch (header) {
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

    return Component.fragment([
      Document.head(children: [Style(styles: _styles)]),
      div(
        classes: 'docs docs-home',
        attributes: {'data-docs-layout': 'home'},
        [
          if (headerComponent case final Component header)
            div(classes: 'header-container', [header]),
          div(classes: 'main-container docs-home-main-container', [
            main_([
              div(classes: 'docs-home-main-grid', [
                div(classes: 'content-container docs-home-content-container', [
                  DocsHomeHero(
                    name: hero.name,
                    text: hero.text,
                    tagline: hero.tagline,
                    actions: hero.actions,
                  ),
                  if (features.isNotEmpty)
                    section(classes: 'docs-home-features', [
                      div(classes: 'docs-home-section-heading', [
                        h2([Component.text('Highlights')]),
                        p([
                          Component.text(
                            'The generated Jaspr site keeps the same polished docs shell, but reshapes it into a focused landing page.',
                          ),
                        ]),
                      ]),
                      div(classes: 'docs-home-features-grid', [
                        for (final feature in features)
                          article(classes: 'docs-home-feature-card', [
                            div(classes: 'docs-home-feature-head', [
                              div(classes: 'docs-home-feature-icon', [
                                Component.text(feature.icon),
                              ]),
                              h3([Component.text(feature.title)]),
                            ]),
                            p([Component.text(feature.details)]),
                          ]),
                      ]),
                    ]),
                  section(classes: 'docs-home-content-panel', [
                    div(classes: 'docs-home-markdown content', [child]),
                  ]),
                  if (footer case final footer?)
                    div(classes: 'docs-home-footer', [footer]),
                ]),
              ]),
            ]),
          ]),
        ],
      ),
    ]);
  }

  _DocsHomeHeroModel _resolveHero(Map<String, Object?> pageData) {
    final heroData = _asStringKeyedMap(pageData['hero']);
    final title = _asNonEmptyString(heroData?['name']) ?? packageName;
    final subtitle =
        _asNonEmptyString(heroData?['text']) ?? 'API Documentation';
    final tagline =
        _asNonEmptyString(heroData?['tagline']) ??
        _asNonEmptyString(pageData['description']) ??
        'Generated with dartdoc_modern';
    final actions = _resolveActions(heroData?['actions']);

    return _DocsHomeHeroModel(
      name: title,
      text: subtitle,
      tagline: tagline,
      actions: actions,
    );
  }

  List<DocsHomeHeroAction> _resolveActions(Object? value) {
    final actions = <DocsHomeHeroAction>[];
    final seen = <String>{};

    void addAction(
      String text,
      String href,
      String theme, {
      bool isExternal = false,
    }) {
      final normalizedHref = _normalizeActionHref(href);
      final key = '$text|$normalizedHref|$theme';
      if (!seen.add(key)) return;
      actions.add(
        DocsHomeHeroAction(
          text: text,
          href: normalizedHref,
          theme: theme,
          isExternal: isExternal,
        ),
      );
    }

    if (value case final List<Object?> rawActions) {
      for (final action in rawActions) {
        final map = _asStringKeyedMap(action);
        if (map == null) continue;

        final text = _asNonEmptyString(map['text']);
        var href = _asNonEmptyString(map['link']);
        if (text == null || href == null) continue;

        if (_looksLikeGuideHref(href)) {
          if (!hasGuideLinks) continue;
          href = primaryActionHref;
        } else if (_looksLikeApiHref(href)) {
          href = apiHref;
        }

        final theme = switch (_asNonEmptyString(map['theme'])) {
          'brand' => 'brand',
          _ => 'alt',
        };
        final isExternal = _isExternalHref(href);
        addAction(text, href, theme, isExternal: isExternal);
      }
    }

    if (actions.isEmpty) {
      if (hasGuideLinks) {
        addAction('Get Started', primaryActionHref, 'brand');
      }
      addAction('API Reference', apiHref, hasGuideLinks ? 'alt' : 'brand');
    } else {
      final hasApiAction = actions.any((action) => action.href == apiHref);
      if (!hasApiAction) {
        addAction('API Reference', apiHref, hasGuideLinks ? 'alt' : 'brand');
      }
    }

    return actions;
  }

  List<_DocsHomeFeature> _resolveFeatures(Object? value) {
    if (value case final List<Object?> rawFeatures) {
      return [
        for (final feature in rawFeatures)
          if (_asStringKeyedMap(feature) case final map?)
            if (_asNonEmptyString(map['title']) case final title?)
              if (_asNonEmptyString(map['details']) case final details?)
                _DocsHomeFeature(
                  icon: _asNonEmptyString(map['icon']) ?? '•',
                  title: title,
                  details: details,
                ),
      ];
    }

    return const [];
  }

  Map<String, Object?>? _asStringKeyedMap(Object? value) {
    if (value is! Map<Object?, Object?>) return null;
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  String? _asNonEmptyString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  bool _looksLikeGuideHref(String href) {
    return href == '/guide' || href == '/guide/' || href.startsWith('/guide/');
  }

  bool _looksLikeApiHref(String href) {
    return href == '/api' || href == '/api/';
  }

  bool _isExternalHref(String href) {
    return href.startsWith('http://') ||
        href.startsWith('https://') ||
        href.startsWith('mailto:') ||
        href.startsWith('tel:');
  }

  String _normalizeActionHref(String href) {
    if (_isExternalHref(href) || href.startsWith('#')) return href;
    if (href.length > 1 && href.endsWith('/')) {
      return href.substring(0, href.length - 1);
    }
    return href;
  }

  static List<StyleRule> get _styles => [
    ...docsResponsiveRootStyles(),
    ...docsHeaderShellStyles(),
    ...docsSearchStyles(),
    css('.docs').styles(
      backgroundColor: Color('var(--background)'),
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
    css(
      '.main-container main',
    ).styles(width: 100.percent, raw: {'overflow': 'visible'}),
    css('.docs-home-main-grid').styles(
      maxWidth: 100.percent,
      margin: Margin.zero,
      raw: {
        'max-width': 'var(--docs-shell-main-max-width)',
        'margin': '0 auto',
        'padding':
            'var(--docs-shell-main-pad-top) var(--docs-shell-main-pad-inline) var(--docs-shell-main-pad-bottom)',
      },
    ),
    css('.docs-home-content-container').styles(
      width: 100.percent,
      minWidth: Unit.zero,
      padding: Padding.only(top: 1.55.rem, bottom: 3.rem),
      display: Display.flex,
      flexDirection: FlexDirection.column,
      gap: Gap.all(1.6.rem),
    ),
    css('.docs-home-features').styles(
      display: Display.flex,
      flexDirection: FlexDirection.column,
      gap: Gap.all(1.1.rem),
    ),
    css('.docs-home-section-heading').styles(maxWidth: 44.rem),
    css('.docs-home-section-heading h2').styles(
      margin: Margin.zero,
      fontSize: 1.65.rem,
      raw: {'line-height': '1.08', 'letter-spacing': '-0.04em'},
    ),
    css('.docs-home-section-heading p').styles(
      margin: Margin.only(top: 0.72.rem),
      color: Color('var(--docs-shell-muted)'),
      raw: {'line-height': '1.68'},
    ),
    css('.docs-home-features-grid').styles(
      display: Display.grid,
      gap: Gap.all(1.rem),
      raw: {'grid-template-columns': 'repeat(4, minmax(0, 1fr))'},
    ),
    css('.docs-home-feature-card').styles(
      display: Display.flex,
      flexDirection: FlexDirection.column,
      gap: Gap.all(0.65.rem),
      padding: Padding.all(1.15.rem),
      radius: BorderRadius.circular(1.2.rem),
      border: Border.all(width: 1.px, color: Color('var(--docs-shell-border)')),
      backgroundColor: Color('var(--docs-shell-surface)'),
      raw: {
        'box-shadow':
            '0 20px 45px color-mix(in srgb, var(--docs-shell-shadow) 96%, transparent)',
      },
    ),
    css('.docs-home-feature-head').styles(
      display: Display.flex,
      alignItems: AlignItems.center,
      gap: Gap.column(0.8.rem),
      minWidth: Unit.zero,
    ),
    css('.docs-home-feature-icon').styles(
      display: Display.inlineFlex,
      alignItems: AlignItems.center,
      justifyContent: JustifyContent.center,
      width: 2.7.rem,
      height: 2.7.rem,
      raw: {'flex': '0 0 auto'},
      radius: BorderRadius.circular(0.95.rem),
      backgroundColor: Color('var(--docs-shell-accent-soft)'),
      fontSize: 1.25.rem,
    ),
    css('.docs-home-feature-card h3').styles(
      margin: Margin.zero,
      fontSize: 1.02.rem,
      fontWeight: FontWeight.w800,
      raw: {'line-height': '1.3', 'text-wrap': 'balance'},
    ),
    css('.docs-home-feature-card p').styles(
      margin: Margin.zero,
      color: Color('var(--docs-shell-muted)'),
      fontSize: 0.95.rem,
      raw: {'line-height': '1.65'},
    ),
    css('.docs-home-version-switch').styles(
      display: Display.flex,
      gap: Gap.all(0.85.rem),
      flexWrap: FlexWrap.wrap,
    ),
    css('.docs-home-version-btn').styles(
      display: Display.inlineFlex,
      alignItems: AlignItems.center,
      justifyContent: JustifyContent.center,
      padding: Padding.symmetric(vertical: 0.7.rem, horizontal: 1.6.rem),
      fontSize: 0.95.rem,
      fontWeight: FontWeight.w700,
      radius: BorderRadius.circular(999.px),
      textDecoration: TextDecoration.none,
      transition: Transition(
        'background-color, border-color, transform, box-shadow',
        duration: Duration(milliseconds: 150),
      ),
      raw: {'letter-spacing': '-0.01em'},
    ),
    css(
      '.docs-home-version-btn:hover',
    ).styles(raw: {'transform': 'translateY(-2px)'}),
    css('.docs-home-version-jaspr').styles(
      backgroundColor: Color('#1a73e8'),
      color: Color('white'),
      border: Border.all(width: 1.px, color: Color('#1a73e8')),
      shadow: BoxShadow(
        offsetX: Unit.zero,
        offsetY: 8.px,
        blur: 24.px,
        color: Color('rgba(26, 115, 232, 0.35)'),
      ),
    ),
    css('.docs-home-version-jaspr:hover').styles(
      backgroundColor: Color('#1565c0'),
      border: Border.all(width: 1.px, color: Color('#1565c0')),
    ),
    css('.docs-home-version-vitepress').styles(
      backgroundColor: Color('var(--docs-shell-surface-elevated)'),
      color: Color('#5c6bc0'),
      border: Border.all(width: 1.5.px, color: Color('#5c6bc0')),
      shadow: BoxShadow(
        offsetX: Unit.zero,
        offsetY: 8.px,
        blur: 24.px,
        color: Color('var(--docs-shell-shadow)'),
      ),
    ),
    css(
      '.docs-home-version-vitepress:hover',
    ).styles(backgroundColor: Color('#5c6bc0'), color: Color('white')),
    css('.docs-home-content-panel').styles(
      width: 100.percent,
      padding: Padding.only(top: 0.8.rem, bottom: 0.8.rem),
      raw: {
        'box-sizing': 'border-box',
        'overflow': 'visible',
        'background': 'transparent',
        'border': 'none',
        'box-shadow': 'none',
      },
    ),
    css('.docs-home-markdown').styles(
      width: 100.percent,
      maxWidth: 62.rem,
      margin: Margin.symmetric(horizontal: Unit.auto),
    ),
    css(
      '.docs-home-markdown > :first-child',
    ).styles(margin: Margin.only(top: Unit.zero)),
    css('.docs-home-markdown .tabs').styles(margin: Margin.only(top: 1.rem)),
    css('.docs-home-markdown .tab-bar').styles(
      display: Display.flex,
      alignItems: AlignItems.center,
      gap: Gap.column(1.25.rem),
      margin: Margin.only(bottom: 1.15.rem),
      padding: Padding.zero,
      border: Border.only(
        bottom: BorderSide(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
      ),
      backgroundColor: Color('transparent'),
      radius: BorderRadius.circular(Unit.zero),
      raw: {'overflow-x': 'auto', 'overflow-y': 'hidden'},
    ),
    css('.docs-home-markdown .tab-bar button').styles(
      padding: Padding.only(bottom: 0.7.rem),
      raw: {'white-space': 'nowrap', 'border': 'none'},
      backgroundColor: Color('transparent'),
      radius: BorderRadius.circular(Unit.zero),
      color: Color('var(--docs-shell-muted)'),
      fontWeight: FontWeight.w800,
      fontSize: 1.02.rem,
    ),
    css('.docs-home-markdown .tab-bar button[active]').styles(
      color: Color('var(--docs-shell-accent-strong)'),
      border: Border.only(
        bottom: BorderSide(
          width: 3.px,
          color: Color('var(--docs-shell-accent)'),
        ),
      ),
      backgroundColor: Color('transparent'),
    ),
    css(
      '.docs-home-markdown .tab-content',
    ).styles(margin: Margin.only(top: 0.4.rem)),
    css(
      '.docs-home-markdown .content > :first-child',
    ).styles(margin: Margin.only(top: Unit.zero)),
    css('.docs-home-markdown h2#install + .code-block').styles(
      margin: Margin.only(top: 0.45.rem, bottom: 1.55.rem),
    ),
    css(
      '.docs-home-markdown h2#install + .code-block button',
    ).styles(display: Display.none),
    css('.docs-home-markdown h2#install + .code-block pre').styles(
      backgroundColor: Color('transparent'),
      raw: {'border': 'none', 'box-shadow': 'none', 'border-radius': '0'},
    ),
    css(
      '.docs-home-markdown h2#install + .code-block code',
    ).styles(padding: Padding.zero, raw: {'background': 'transparent'}),
    css('.content h2').styles(
      margin: Margin.only(top: 2.3.rem, bottom: 0.85.rem),
      raw: {'letter-spacing': '-0.03em'},
    ),
    css('.content h3').styles(
      margin: Margin.only(top: 1.8.rem, bottom: 0.65.rem),
      raw: {'letter-spacing': '-0.02em'},
    ),
    css('.code-block', [
      css('&').styles(
        position: Position.relative(),
        margin: Margin.only(top: 1.rem, bottom: 1.4.rem),
        raw: {'isolation': 'isolate'},
      ),
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
        radius: BorderRadius.circular(0.72.rem),
        backgroundColor: Color('var(--docs-shell-code-button-bg)'),
        color: Color('var(--docs-shell-code-button-fg)'),
        cursor: Cursor.pointer,
        zIndex: ZIndex(1),
        shadow: BoxShadow(
          offsetX: Unit.zero,
          offsetY: 12.px,
          blur: 26.px,
          color: Color('var(--docs-shell-shadow)'),
        ),
        transition: Transition(
          'opacity, background-color, border-color',
          duration: Duration(milliseconds: 150),
        ),
        raw: {'opacity': '0'},
      ),
      css('&:hover button').styles(opacity: 1),
      css('pre').styles(margin: Margin.zero),
    ]),
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
        raw: {'width': '1%', 'min-width': '12rem', 'white-space': 'nowrap'},
      ),
      css('tbody tr:last-child td').styles(border: Border.unset),
      css(
        'tbody tr:hover td',
      ).styles(backgroundColor: Color('var(--docs-shell-accent-soft)')),
      css('th:first-child, td:first-child').styles(fontWeight: FontWeight.w600),
      css('tbody td a').styles(fontWeight: FontWeight.w600),
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
    css('.docs-home-footer').styles(
      padding: Padding.only(top: 0.3.rem),
      color: Color('var(--docs-shell-muted)'),
    ),
    downWide([
      css(
        '.docs-home-features-grid',
      ).styles(raw: {'grid-template-columns': 'repeat(3, minmax(0, 1fr))'}),
    ]),
    downContent([
      css(
        '.docs-home-features-grid',
      ).styles(raw: {'grid-template-columns': 'repeat(2, minmax(0, 1fr))'}),
      css('.docs-home-main-grid').styles(
        raw: {
          'padding':
              'var(--docs-shell-main-pad-top) var(--docs-shell-main-pad-inline) var(--docs-shell-main-pad-bottom)',
        },
      ),
      css('.docs-home-content-panel').styles(
        padding: Padding.only(top: 0.65.rem, bottom: 0.65.rem),
      ),
    ]),
    downMobile([
      css('.docs-home-content-container').styles(
        padding: Padding.only(top: 1.15.rem, bottom: 2.rem),
        gap: Gap.all(1.15.rem),
      ),
      css(
        '.docs-home-features-grid',
      ).styles(raw: {'grid-template-columns': 'minmax(0, 1fr)'}),
      css('.docs-home-content-panel').styles(
        padding: Padding.only(top: 0.55.rem, bottom: 0.55.rem),
        raw: {'border-radius': '0'},
      ),
    ]),
  ];
}

class _DocsHomeHeroModel {
  const _DocsHomeHeroModel({
    required this.name,
    required this.text,
    required this.tagline,
    required this.actions,
  });

  final String name;
  final String text;
  final String tagline;
  final List<DocsHomeHeroAction> actions;
}

class _DocsHomeFeature {
  const _DocsHomeFeature({
    required this.icon,
    required this.title,
    required this.details,
  });

  final String icon;
  final String title;
  final String details;
}
