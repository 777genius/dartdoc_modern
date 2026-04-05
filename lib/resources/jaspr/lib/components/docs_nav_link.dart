import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:universal_web/web.dart' as web;

import '../docs_base.dart';

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
    final resolvedTo = _resolveHref(to);
    final isExternal = _isExternalTarget(to);
    final isHashOnly = to.startsWith('#');
    final useClientRouter = !hasDocsBasePath;
    final isPlainAnchorOnly =
        isExternal || isHashOnly || target == Target.blank || !useClientRouter;
    final mergedAttributes = {
      ...?attributes,
      'data-docs-nav-link': 'true',
      if (replace) 'data-docs-nav-replace': 'true',
    };

    final events = <String, EventCallback>{
      if (preload && !isPlainAnchorOnly)
        'mouseover': (event) {
          final router = Router.maybeOf(context);
          if (router != null) {
            router.preload(to);
          }
        },
      if (onMouseEnter != null) 'mouseenter': onMouseEnter!,
      if (!isPlainAnchorOnly)
        'click': (event) {
          if (_isModifiedClick(event)) return;

          onNavigate?.call();

          final router = Router.maybeOf(context);
          if (router == null) return;

          event.preventDefault();
          if (replace) {
            router.replace(to, extra: extra);
          } else {
            router.push(to, extra: extra);
          }
        },
    };

    return a(
      href: resolvedTo,
      target: target,
      classes: classes,
      attributes: mergedAttributes,
      events: events,
      [
        if (child != null) child!,
        ...?children,
      ],
    );
  }

  bool _isExternalTarget(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('mailto:') ||
        value.startsWith('tel:');
  }

  String _resolveHref(String value) {
    if (_isExternalTarget(value) || value.startsWith('#')) {
      return withDocsBasePath(value);
    }

    final hashIndex = value.indexOf('#');
    final queryIndex = value.indexOf('?');
    final splitIndex = switch ((hashIndex, queryIndex)) {
      (-1, -1) => -1,
      (final hash, -1) => hash,
      (-1, final query) => query,
      (final hash, final query) => hash < query ? hash : query,
    };

    final pathPart = splitIndex == -1 ? value : value.substring(0, splitIndex);
    final suffix = splitIndex == -1 ? '' : value.substring(splitIndex);
    final normalized = withDocsBasePath(pathPart);

    if (normalized == '/' || normalized.endsWith('/')) {
      return '$normalized$suffix';
    }

    final lastSegment = normalized.split('/').last;
    final looksLikeFile = lastSegment.contains('.');
    if (looksLikeFile) {
      return '$normalized$suffix';
    }

    return '$normalized/$suffix';
  }

  bool _isModifiedClick(web.Event event) {
    if (event is! web.MouseEvent) return false;

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
