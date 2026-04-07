import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Small, muted "Generated with dartdoc_modern" credit shown at the bottom
/// of every page rendered by the default layouts.
///
/// Self-contained: ships its own [Style] block so it can be dropped into
/// any layout without extra CSS wiring.
class DartdocModernFooter extends StatelessComponent {
  const DartdocModernFooter({super.key});

  static const String _projectUrl =
      'https://github.com/777genius/dartdoc_modern';

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      Document.head(children: [Style(styles: _styles)]),
      div(classes: 'docs-generated-footer', [
        span([
          Component.text('Generated with '),
          a(
            href: _projectUrl,
            target: Target.blank,
            attributes: const {'rel': 'noopener noreferrer'},
            classes: 'docs-generated-footer-link',
            [Component.text('dartdoc_modern')],
          ),
        ]),
      ]),
    ]);
  }

  static final List<StyleRule> _styles = [
    css('.docs-generated-footer').styles(
      display: Display.flex,
      justifyContent: JustifyContent.center,
      padding: Padding.only(top: 1.5.rem, bottom: 0.25.rem),
      margin: Margin.only(top: 2.rem),
      fontSize: 0.8.rem,
      color: Color('var(--docs-shell-muted)'),
      border: Border.only(
        top: BorderSide(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
      ),
      raw: {
        'text-align': 'center',
        'opacity': '0.85',
      },
    ),
    css('.docs-generated-footer-link').styles(
      color: Color('var(--docs-shell-muted)'),
      raw: {
        'text-decoration': 'underline',
        'text-underline-offset': '0.2em',
      },
    ),
    css('.docs-generated-footer-link:hover').styles(
      color: Color('var(--docs-shell-accent)'),
    ),
    css('.docs-generated-footer-link:visited').styles(
      color: Color('var(--docs-shell-muted)'),
    ),
  ];
}
