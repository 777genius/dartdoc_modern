import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../docs_base.dart';
import '../project_version_routes.dart';

@client
class DocsNavigationRuntime extends StatefulComponent {
  const DocsNavigationRuntime({super.key});

  @override
  State<DocsNavigationRuntime> createState() => _DocsNavigationRuntimeState();
}

class _DocsNavigationRuntimeState extends State<DocsNavigationRuntime> {
  JSFunction? _clickListener;
  JSFunction? _popStateListener;
  int _navigationToken = 0;
  static const _sidebarSyncEvent = 'docs:sidebar-sync';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    web.document.documentElement?.setAttribute(
      'data-docs-nav-runtime-ready',
      '',
    );

    _clickListener = ((web.Event rawEvent) {
      if (rawEvent is! web.MouseEvent) return;
      if (_isModifiedClick(rawEvent)) return;

      final target = _resolveTargetElement(rawEvent.target);
      if (target == null) return;

      final closeSidebar = target.closest('[data-docs-sidebar-close]');
      if (closeSidebar != null) {
        rawEvent.preventDefault();
        _closeSidebar();
        return;
      }

      final barrier = target.closest('[data-docs-sidebar-barrier]');
      if (barrier != null) {
        rawEvent.preventDefault();
        _closeSidebar();
        return;
      }

      final anchor = target.closest('a[data-docs-nav-link]');
      if (anchor is! web.HTMLAnchorElement) return;
      if (!_shouldHandleClientNavigation(anchor)) return;

      rawEvent.preventDefault();
      unawaited(
        _navigateTo(
          Uri.parse(anchor.href),
          replace: anchor.hasAttribute('data-docs-nav-replace'),
        ),
      );
    }).toJS;
    web.document.addEventListener('click', _clickListener);
    _normalizeDocumentAnchors();
    _syncHeaderNavActive();
    _syncVersionSwitchRoutes();

    _popStateListener = ((web.Event _) {
      unawaited(
        _navigateTo(
          Uri.parse(web.window.location.href),
          updateHistory: false,
          restoreScroll: true,
        ),
      );
    }).toJS;
    web.window.addEventListener('popstate', _popStateListener);
  }

  @override
  void dispose() {
    web.document.documentElement?.removeAttribute(
      'data-docs-nav-runtime-ready',
    );
    if (_clickListener != null) {
      web.document.removeEventListener('click', _clickListener);
      _clickListener = null;
    }
    if (_popStateListener != null) {
      web.window.removeEventListener('popstate', _popStateListener);
      _popStateListener = null;
    }
    super.dispose();
  }

  @override
  Component build(BuildContext context) => span(
    attributes: {'hidden': 'hidden', 'data-docs-nav-runtime': ''},
    const [],
  );

  bool _shouldHandleClientNavigation(web.HTMLAnchorElement anchor) {
    final rawHref = anchor.getAttribute('href');
    if (rawHref == null || rawHref.isEmpty) return false;
    if (rawHref.startsWith('#')) return false;
    if (anchor.target == '_blank') return false;
    if (anchor.hasAttribute('download')) return false;
    if (rawHref.startsWith('mailto:') || rawHref.startsWith('tel:'))
      return false;

    final targetUri = Uri.parse(anchor.href);
    final currentUri = Uri.parse(web.window.location.href);
    if (targetUri.scheme != currentUri.scheme ||
        targetUri.host != currentUri.host) {
      return false;
    }

    final samePath =
        targetUri.path == currentUri.path &&
        targetUri.query == currentUri.query;
    if (samePath && targetUri.fragment.isNotEmpty) return false;

    return true;
  }

  bool _isModifiedClick(web.MouseEvent event) {
    return event.button != 0 ||
        event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey;
  }

  web.Element? _resolveTargetElement(web.EventTarget? target) {
    if (target is web.Element) return target;
    if (target is web.Node) return target.parentElement;
    return null;
  }

  Future<void> _navigateTo(
    Uri targetUri, {
    bool replace = false,
    bool updateHistory = true,
    bool restoreScroll = false,
  }) async {
    final token = ++_navigationToken;
    _setBusy(true);

    try {
      final response = await http.get(Uri.parse(targetUri.toString()));
      if (token != _navigationToken) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _hardNavigate(
          targetUri,
          replace: replace,
          updateHistory: updateHistory,
        );
        return;
      }

      final nextDocument = web.DOMParser().parseFromString(
        utf8.decode(response.bodyBytes).toJS,
        'text/html',
      );
      final currentLayout = _resolveDocumentLayout(web.document);
      final targetLayout = _resolveDocumentLayout(nextDocument);
      if (currentLayout != null &&
          targetLayout != null &&
          currentLayout != targetLayout) {
        _hardNavigate(
          targetUri,
          replace: replace,
          updateHistory: updateHistory,
        );
        return;
      }

      final nextMain = nextDocument.querySelector('.main-container');
      final currentMain = web.document.querySelector('.main-container');
      if (nextMain == null || currentMain == null) {
        _hardNavigate(
          targetUri,
          replace: replace,
          updateHistory: updateHistory,
        );
        return;
      }

      currentMain.replaceWith(nextMain);
      _normalizeDocumentAnchors(root: nextMain);

      final nextTitle = nextDocument.querySelector('title')?.textContent;
      if (nextTitle != null && nextTitle.isNotEmpty) {
        web.document.title = nextTitle;
      } else {
        final fallbackTitle = nextDocument
            .querySelector('.content-header h1, .content h1')
            ?.textContent;
        if (fallbackTitle != null && fallbackTitle.isNotEmpty) {
          web.document.title = fallbackTitle;
        }
      }

      if (updateHistory) {
        if (replace) {
          web.window.history.replaceState(null, '', targetUri.toString());
        } else {
          web.window.history.pushState(null, '', targetUri.toString());
        }
      }

      _closeSidebar();
      _syncHeaderNavActive();
      _syncVersionSwitchRoutes();
      _notifyNavigation();
      _syncScroll(targetUri, restoreScroll: restoreScroll);
    } catch (_) {
      if (token != _navigationToken) return;
      _hardNavigate(targetUri, replace: replace, updateHistory: updateHistory);
    } finally {
      if (token == _navigationToken) {
        _setBusy(false);
      }
    }
  }

  void _hardNavigate(
    Uri targetUri, {
    required bool replace,
    required bool updateHistory,
  }) {
    if (!updateHistory) {
      web.window.location.replace(targetUri.toString());
      return;
    }
    if (replace) {
      web.window.location.replace(targetUri.toString());
    } else {
      web.window.location.assign(targetUri.toString());
    }
  }

  void _setBusy(bool value) {
    final root = web.document.documentElement;
    if (root == null) return;
    if (value) {
      root.setAttribute('data-docs-nav-loading', '');
    } else {
      root.removeAttribute('data-docs-nav-loading');
    }
  }

  void _closeSidebar() {
    final sidebar = web.document.querySelector('.sidebar-container');
    sidebar?.classList.remove('open');
    web.document.body?.classList.remove('sidebar-open');
    web.document.body?.style.overflow = '';
    _syncSidebarToggle();
  }

  void _notifyNavigation() {
    web.window.dispatchEvent(web.CustomEvent('docs:navigation'));
  }

  void _syncHeaderNavActive() {
    final currentRoute = _normalizeRoute(web.window.location.pathname);
    final navLinks = web.document.querySelectorAll(
      '.header-nav a[data-docs-header-nav-link]',
    );

    for (var index = 0; index < navLinks.length; index++) {
      final node = navLinks.item(index);
      if (node is! web.HTMLAnchorElement) continue;

      final href = node.getAttribute('href') ?? node.href;
      final hrefRoute = _normalizeRoute(href);
      final primaryPrefix = node.getAttribute('data-docs-match-prefix');
      final extraPrefixes =
          node
              .getAttribute('data-docs-match-prefixes')
              ?.split('|')
              .where((value) => value.trim().isNotEmpty)
              .toList() ??
          const <String>[];

      final isActive =
          hrefRoute == currentRoute ||
          (primaryPrefix != null &&
              _matchesSectionPath(
                currentRoute,
                _normalizeRoute(primaryPrefix),
              )) ||
          extraPrefixes.any(
            (prefix) =>
                _matchesSectionPath(currentRoute, _normalizeRoute(prefix)),
          );

      node.classList.toggle('active', isActive);
      if (isActive) {
        node.setAttribute('aria-current', 'page');
      } else {
        node.removeAttribute('aria-current');
      }
    }
  }

  void _syncVersionSwitchRoutes() {
    final currentRoute = _currentRouteForVersionSwitch();
    final versionLinks = web.document.querySelectorAll(
      '.version-switch a[data-version]',
    );

    for (var index = 0; index < versionLinks.length; index++) {
      final node = versionLinks.item(index);
      if (node is! web.HTMLAnchorElement) continue;

      final version = node.getAttribute('data-version');
      final href = switch (version) {
        'jaspr' => projectJasprUrlForRoute(currentRoute),
        'vitepress' => projectVitePressUrlForRoute(currentRoute),
        _ => null,
      };
      if (href == null || href.isEmpty) continue;
      node.setAttribute('href', href);
    }
  }

  String _currentRouteForVersionSwitch() {
    final location = web.window.location;
    final path = _normalizeRoute(location.pathname);
    final search = location.search;
    final hash = location.hash;

    return '$path$search$hash';
  }

  String _normalizeRoute(String route) {
    final withoutFragment = route.split('#').first.split('?').first;
    final normalizedPath = stripDocsBasePath(withoutFragment);
    if (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      return normalizedPath.substring(0, normalizedPath.length - 1);
    }
    return normalizedPath.isEmpty ? '/' : normalizedPath;
  }

  bool _matchesSectionPath(String route, String prefix) {
    if (route == prefix) return true;
    if (prefix == '/') return route == '/';
    return route.startsWith('$prefix/');
  }

  void _syncSidebarToggle() {
    web.window.dispatchEvent(web.CustomEvent(_sidebarSyncEvent));
  }

  void _normalizeDocumentAnchors({web.Element? root}) {
    final scope = root ?? web.document.documentElement;
    if (scope == null) return;

    final nodes = scope.querySelectorAll('a[href]');
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes.item(i);
      if (node is! web.HTMLAnchorElement) continue;

      final rawHref = node.getAttribute('href');
      if (rawHref == null || rawHref.isEmpty) continue;
      if (_isExternalHref(rawHref) || rawHref.startsWith('#')) continue;

      if (rawHref.startsWith('/')) {
        node.setAttribute('href', withDocsBasePath(rawHref));
      }

      if (node.target == '_blank' || node.hasAttribute('download')) continue;
      node.setAttribute('data-docs-nav-link', 'true');
    }
  }

  void _syncScroll(Uri targetUri, {required bool restoreScroll}) {
    if (targetUri.fragment.isNotEmpty) {
      final node = web.document.getElementById(targetUri.fragment);
      if (node != null) {
        node.scrollIntoView();
        return;
      }
    }

    if (!restoreScroll) {
      web.window.scrollTo(0.toJS, 0);
    }
  }

  bool _isExternalHref(String href) {
    return href.startsWith('http://') ||
        href.startsWith('https://') ||
        href.startsWith('mailto:') ||
        href.startsWith('tel:');
  }

  String? _resolveDocumentLayout(web.Document document) {
    final root = document.querySelector('[data-docs-layout]');
    final layout = root?.getAttribute('data-docs-layout')?.trim();
    if (layout == null || layout.isEmpty) return null;
    return layout;
  }
}
