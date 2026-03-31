import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

class DocsNavLink extends StatelessComponent {
  const DocsNavLink({
    required this.to,
    this.replace = false,
    this.extra,
    this.preload = true,
    this.target,
    this.classes,
    this.attributes,
    this.onNavigate,
    this.onMouseEnter,
    this.child,
    this.children,
    super.key,
  });

  final String to;
  final bool replace;
  final Object? extra;
  final bool preload;
  final Target? target;
  final String? classes;
  final Map<String, String>? attributes;
  final VoidCallback? onNavigate;
  final EventCallback? onMouseEnter;
  final Component? child;
  final List<Component>? children;

  @override
  Component build(BuildContext context) {
    final isExternal = _isExternalTarget(to);
    final isHashOnly = to.startsWith('#');
    final isPlainAnchorOnly = isExternal || isHashOnly || target == Target.blank;
    final mergedAttributes = {
      ...?attributes,
      'data-docs-nav-link': 'true',
      if (replace) 'data-docs-nav-replace': 'true',
    };

    return a(
      href: to,
      target: target,
      classes: classes,
      attributes: mergedAttributes,
      events: {
        if (preload && !isPlainAnchorOnly)
          'mouseover': (event) {
            final router = Router.maybeOf(context);
            if (router != null) {
              router.preload(to);
            }
          },
        if (onMouseEnter != null) 'mouseenter': onMouseEnter!,
        'click': (event) {
          if (_isModifiedClick(event)) return;

          onNavigate?.call();
          if (isPlainAnchorOnly) return;

          final router = Router.maybeOf(context);
          if (router == null) return;

          event.preventDefault();
          if (replace) {
            router.replace(to, extra: extra);
          } else {
            router.push(to, extra: extra);
          }
        },
      },
      [?child, ...?children],
    );
  }

  bool _isExternalTarget(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('mailto:') ||
        value.startsWith('tel:');
  }

  bool _isModifiedClick(dynamic event) {
    final button = event.button;
    final metaKey = event.metaKey;
    final ctrlKey = event.ctrlKey;
    final shiftKey = event.shiftKey;
    final altKey = event.altKey;

    return button == 1 ||
        button == 2 ||
        metaKey == true ||
        ctrlKey == true ||
        shiftKey == true ||
        altKey == true;
  }
}
