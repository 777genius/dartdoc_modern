import 'dart:js_interop';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

@client
class DocsSidebarToggleRuntime extends StatefulComponent {
  const DocsSidebarToggleRuntime({super.key});

  @override
  State<DocsSidebarToggleRuntime> createState() =>
      _DocsSidebarToggleRuntimeState();
}

class _DocsSidebarToggleRuntimeState extends State<DocsSidebarToggleRuntime> {
  static const _sidebarSyncEvent = 'docs:sidebar-sync';

  JSFunction? _clickListener;
  JSFunction? _syncListener;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _clickListener = ((web.Event rawEvent) {
      if (rawEvent is! web.MouseEvent) return;

      final target = _resolveTargetElement(rawEvent.target);
      if (target == null) return;
      if (target.closest('[data-docs-sidebar-toggle]') == null) return;

      rawEvent.preventDefault();
      _toggleSidebar();
    }).toJS;
    web.document.addEventListener('click', _clickListener);

    _syncListener = ((web.Event _) {
      _syncButtonState();
    }).toJS;
    web.window.addEventListener(_sidebarSyncEvent, _syncListener);

    _syncButtonState();
  }

  @override
  void dispose() {
    if (_clickListener != null) {
      web.document.removeEventListener('click', _clickListener);
      _clickListener = null;
    }
    if (_syncListener != null) {
      web.window.removeEventListener(_sidebarSyncEvent, _syncListener);
      _syncListener = null;
    }
    super.dispose();
  }

  @override
  Component build(BuildContext context) => span(
        attributes: {
          'hidden': 'hidden',
          'data-docs-sidebar-toggle-runtime': '',
        },
        const [],
      );

  web.Element? _resolveTargetElement(web.EventTarget? target) {
    if (target is web.Element) return target;
    if (target is web.Node) return target.parentElement;
    return null;
  }

  void _toggleSidebar() {
    final sidebar = web.document.querySelector('.sidebar-container');
    if (sidebar == null) return;

    final isOpen =
        sidebar.classList.contains('open') ||
        web.document.body?.classList.contains('sidebar-open') == true;

    if (isOpen) {
      sidebar.classList.remove('open');
      web.document.body?.classList.remove('sidebar-open');
      web.document.body?.style.overflow = '';
    } else {
      sidebar.classList.add('open');
      web.document.body?.classList.add('sidebar-open');
      web.document.body?.style.overflow = 'hidden';
    }

    _emitSync();
  }

  void _emitSync() {
    _syncButtonState();
    web.window.dispatchEvent(web.CustomEvent(_sidebarSyncEvent));
  }

  void _syncButtonState() {
    final button = web.document.querySelector('[data-docs-sidebar-toggle]');
    final sidebar = web.document.querySelector('.sidebar-container');
    if (button == null) return;

    final isOpen =
        sidebar?.classList.contains('open') == true ||
        web.document.body?.classList.contains('sidebar-open') == true;
    button.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    button.setAttribute(
      'aria-label',
      isOpen ? 'Close navigation menu' : 'Open navigation menu',
    );
  }
}
