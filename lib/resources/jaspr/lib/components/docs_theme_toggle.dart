import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

@client
class DocsThemeToggle extends StatefulComponent {
  const DocsThemeToggle({super.key});

  @override
  State<DocsThemeToggle> createState() => _DocsThemeToggleState();
}

class _DocsThemeToggleState extends State<DocsThemeToggle> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _isDark = _resolveTheme() == 'dark';
  }

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      if (!kIsWeb)
        Document.head(
          children: [
            script(
              id: 'docs-theme-script',
              content: '''
                const storedTheme = window.localStorage.getItem('jaspr:theme');
                const resolvedTheme = storedTheme ?? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
                document.documentElement.setAttribute('data-theme', resolvedTheme);
              ''',
            ),
          ],
        ),
      if (kIsWeb)
        Document.html(attributes: {'data-theme': _isDark ? 'dark' : 'light'}),
      button(
        classes: 'theme-toggle',
        attributes: {
          'type': 'button',
          'data-docs-theme-toggle': '',
          'aria-label': _isDark
              ? 'Switch to light theme'
              : 'Switch to dark theme',
          'title': _isDark ? 'Switch to light theme' : 'Switch to dark theme',
        },
        onClick: _toggle,
        [
          span(
            classes: 'theme-toggle-icon',
            styles: Styles(display: _isDark ? Display.none : null),
            [RawText(_moonIcon)],
          ),
          span(
            classes: 'theme-toggle-icon',
            styles: Styles(display: _isDark ? null : Display.none),
            [RawText(_sunIcon)],
          ),
        ],
      ),
    ]);
  }

  void _toggle() {
    setState(() {
      _isDark = !_isDark;
    });
    if (!kIsWeb) return;
    final theme = _isDark ? 'dark' : 'light';
    web.window.localStorage.setItem('jaspr:theme', theme);
    web.document.documentElement?.setAttribute('data-theme', theme);
  }

  String _resolveTheme() {
    final explicit = web.window.localStorage.getItem('jaspr:theme');
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return web.window.matchMedia('(prefers-color-scheme: dark)').matches
        ? 'dark'
        : 'light';
  }
}

const _moonIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"></path></svg>
''';

const _sunIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2.5"></path><path d="M12 19.5V22"></path><path d="m4.93 4.93 1.77 1.77"></path><path d="m17.3 17.3 1.77 1.77"></path><path d="M2 12h2.5"></path><path d="M19.5 12H22"></path><path d="m6.7 17.3-1.77 1.77"></path><path d="m19.07 4.93-1.77 1.77"></path></svg>
''';
