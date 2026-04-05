import 'package:jaspr/dom.dart';

const docsCompactBreakpoint = 479;
const docsMobileBreakpoint = 767;
const docsContentBreakpoint = 1023;
const docsWideBreakpoint = 1180;

StyleRule downCompact(List<StyleRule> rules) => css.media(
      MediaQuery.all(maxWidth: docsCompactBreakpoint.px),
      rules,
    );

StyleRule downMobile(List<StyleRule> rules) => css.media(
      MediaQuery.all(maxWidth: docsMobileBreakpoint.px),
      rules,
    );

StyleRule downContent(List<StyleRule> rules) => css.media(
      MediaQuery.all(maxWidth: docsContentBreakpoint.px),
      rules,
    );

StyleRule downWide(List<StyleRule> rules) => css.media(
      MediaQuery.all(maxWidth: docsWideBreakpoint.px),
      rules,
    );

List<StyleRule> docsResponsiveRootStyles() => [
      css('.docs').styles(
        raw: {
          '--docs-shell-header-height': '3.75rem',
          '--docs-shell-header-block-pad': '0.75rem',
          '--docs-shell-header-inline-pad': '1.5rem',
          '--docs-shell-gutter': '1.5rem',
          '--docs-shell-main-max-width':
              'min(101rem, calc(100vw - calc(var(--docs-shell-gutter) * 2)))',
          '--docs-shell-grid-gap': '1.5rem',
          '--docs-shell-toc-width': '11.25rem',
          '--docs-shell-sidebar-width': '19rem',
          '--docs-shell-drawer-width': '20.5rem',
          '--docs-shell-main-pad-top': '0.75rem',
          '--docs-shell-main-pad-bottom': '3.5rem',
          '--docs-shell-main-pad-inline': '0.9rem',
          '--docs-shell-content-pad-top': '1.55rem',
          '--docs-shell-content-pad-right': '0.25rem',
          '--docs-shell-content-pad-bottom': '3rem',
          '--docs-shell-sticky-top': '4.7rem',
          '--docs-shell-anchor-offset': '6.45rem',
          '--docs-shell-search-panel-width': '46rem',
          '--docs-shell-search-launcher-min': '8.5rem',
          '--docs-shell-content-header-pad-y': '1.75rem',
          '--docs-shell-content-header-pad-x': '1.8rem',
          '--docs-shell-content-header-radius': '1.5rem',
        },
      ),
      downWide([
        css('.docs').styles(
          raw: {
            '--docs-shell-gutter': '1rem',
            '--docs-shell-main-max-width': 'calc(100vw - 2rem)',
            '--docs-shell-grid-gap': '1rem',
            '--docs-shell-toc-width': '10.5rem',
            '--docs-shell-sidebar-width': '17rem',
          },
        ),
      ]),
      downContent([
        css('.docs').styles(
          raw: {
            '--docs-shell-gutter': '1rem',
            '--docs-shell-main-pad-top': '1.35rem',
            '--docs-shell-main-pad-bottom': '2rem',
            '--docs-shell-main-pad-inline': '1rem',
            '--docs-shell-content-pad-top': '1.15rem',
            '--docs-shell-content-pad-right': '0',
            '--docs-shell-content-pad-bottom': '2rem',
            '--docs-shell-header-inline-pad': '0.9rem',
            '--docs-shell-anchor-offset': '6rem',
            '--docs-shell-search-launcher-min': '7rem',
            '--docs-shell-drawer-width': '20.5rem',
          },
        ),
      ]),
      downMobile([
        css('.docs').styles(
          raw: {
            '--docs-shell-content-header-pad-y': '1.1rem',
            '--docs-shell-content-header-pad-x': '1rem',
            '--docs-shell-content-header-radius': '1.1rem',
          },
        ),
      ]),
      downCompact([
        css('.docs').styles(
          raw: {
            '--docs-shell-gutter': '0.72rem',
            '--docs-shell-header-inline-pad': '0.72rem',
            '--docs-shell-search-launcher-min': '2.2rem',
          },
        ),
      ]),
    ];
