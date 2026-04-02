import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

import 'docs_sidebar_toggle_shared.dart';

@client
class DocsSidebarToggle extends StatefulComponent {
  const DocsSidebarToggle({super.key});

  @override
  State<DocsSidebarToggle> createState() => _DocsSidebarToggleState();
}

class _DocsSidebarToggleState extends State<DocsSidebarToggle> {
  static const _sidebarSyncEvent = 'docs:sidebar-sync';

  bool _isOpen = false;
  JSFunction? _syncListener;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _syncListener = ((web.Event _) {
      _syncFromDom();
    }).toJS;
    web.window.addEventListener(_sidebarSyncEvent, _syncListener);
    _syncFromDom();
  }

  @override
  void dispose() {
    if (_syncListener != null) {
      web.window.removeEventListener(_sidebarSyncEvent, _syncListener);
      _syncListener = null;
    }
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      Document.head(children: [Style(styles: docsSidebarToggleStyles())]),
      button(
        classes: 'sidebar-toggle-button',
        attributes: {
          'type': 'button',
          'data-docs-sidebar-toggle': '',
          'aria-label': _isOpen
              ? 'Close navigation menu'
              : 'Open navigation menu',
          'aria-expanded': _isOpen ? 'true' : 'false',
          'aria-controls': 'docs-sidebar',
        },
        onClick: _toggle,
        [RawText(docsSidebarToggleMenuIcon)],
      ),
    ]);
  }

  void _toggle() {
    if (!kIsWeb) return;
    final sidebar = web.document.querySelector('.sidebar-container');
    if (sidebar == null) return;

    final nextOpen = !_isOpen;
    if (nextOpen) {
      sidebar.classList.add('open');
      web.document.body?.classList.add('sidebar-open');
      web.document.body?.style.overflow = 'hidden';
    } else {
      sidebar.classList.remove('open');
      web.document.body?.classList.remove('sidebar-open');
      web.document.body?.style.overflow = '';
    }
    web.window.dispatchEvent(web.CustomEvent(_sidebarSyncEvent));
  }

  void _syncFromDom() {
    final sidebar = web.document.querySelector('.sidebar-container');
    final isOpen =
        sidebar?.classList.contains('open') == true ||
        web.document.body?.classList.contains('sidebar-open') == true;
    if (_isOpen == isOpen || !mounted) return;
    setState(() {
      _isOpen = isOpen;
    });
  }
}
