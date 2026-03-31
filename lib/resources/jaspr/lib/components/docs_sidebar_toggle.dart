import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../theme/docs_responsive.dart';

@client
class DocsSidebarToggle extends StatefulComponent {
  const DocsSidebarToggle({super.key});

  @override
  State<DocsSidebarToggle> createState() => _DocsSidebarToggleState();
}

class _DocsSidebarToggleState extends State<DocsSidebarToggle> {
  bool _isOpen = false;

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      if (!kIsWeb) Document.head(children: [Style(styles: _styles)]),
      button(
        classes: 'sidebar-toggle-button',
        attributes: {
          'type': 'button',
          'data-docs-sidebar-toggle': '',
          'aria-label':
              _isOpen ? 'Close navigation menu' : 'Open navigation menu',
          'aria-expanded': _isOpen ? 'true' : 'false',
          'aria-controls': 'docs-sidebar',
        },
        onClick: _toggle,
        [RawText(_menuIcon)],
      ),
    ]);
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
    if (!kIsWeb) return;
    final sidebar = web.document.querySelector('.sidebar-container');
    if (sidebar == null) return;
    if (_isOpen) {
      sidebar.classList.add('open');
      web.document.body?.classList.add('sidebar-open');
      web.document.body?.style.overflow = 'hidden';
    } else {
      sidebar.classList.remove('open');
      web.document.body?.classList.remove('sidebar-open');
      web.document.body?.style.overflow = '';
    }
  }

  List<StyleRule> get _styles => [
        css('.sidebar-toggle-button').styles(
          display: Display.none,
          justifyContent: JustifyContent.center,
          alignItems: AlignItems.center,
          width: 2.rem,
          height: 2.rem,
          backgroundColor: Colors.transparent,
          border: Border.none,
          color: Color('inherit'),
          cursor: Cursor.pointer,
          radius: BorderRadius.circular(0.6.rem),
        ),
        css('.sidebar-toggle-button:hover').styles(
          backgroundColor: Color('#0000000d'),
        ),
        css('.sidebar-toggle-button:focus-visible').styles(
          outline: Outline(
            width: OutlineWidth(3.px),
            style: OutlineStyle.solid,
            color: Color('var(--docs-shell-focus)'),
            offset: 2.px,
          ),
        ),
        downContent([
          css('[data-has-sidebar] .sidebar-toggle-button')
              .styles(display: Display.flex),
        ]),
      ];
}

const _menuIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" x2="20" y1="12" y2="12"></line><line x1="4" x2="20" y1="6" y2="6"></line><line x1="4" x2="20" y1="18" y2="18"></line></svg>
''';
