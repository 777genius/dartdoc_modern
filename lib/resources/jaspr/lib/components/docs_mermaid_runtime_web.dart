import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

@JS('mermaid')
external JSObject? get _mermaid;

@client
class DocsMermaidRuntime extends StatefulComponent {
  const DocsMermaidRuntime({super.key});

  @override
  State<DocsMermaidRuntime> createState() => _DocsMermaidRuntimeState();
}

class _DocsMermaidRuntimeState extends State<DocsMermaidRuntime> {
  Timer? _themeTimer;
  String _theme = 'light';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _theme = _currentTheme();
    Timer(const Duration(milliseconds: 50), _renderMermaid);
    _themeTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final nextTheme = _currentTheme();
      if (nextTheme == _theme) return;
      _theme = nextTheme;
      _renderMermaid(force: true);
    });
  }

  @override
  void dispose() {
    _themeTimer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) => Component.fragment(const []);

  String _currentTheme() =>
      web.document.documentElement?.getAttribute('data-theme') == 'dark'
          ? 'dark'
          : 'light';

  Future<void> _renderMermaid({bool force = false}) async {
    final mermaid = _mermaid;
    if (mermaid == null) return;

    mermaid.callMethod(
      'initialize'.toJS,
      <Object?>[
        {
          'startOnLoad': false,
          'theme': _currentTheme() == 'dark' ? 'dark' : 'default',
          'securityLevel': 'loose',
        }.jsify(),
      ].jsify(),
    );

    final nodes = web.document.querySelectorAll('.mermaid-diagram');
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes.item(index);
      if (node is! web.HTMLElement) continue;
      if (!force && node.dataset['rendered'] == 'true') continue;

      final source = utf8.decode(base64Decode(node.dataset['sourceBase64']));
      final renderId = 'mermaid-${index + 1}-${DateTime.now().millisecondsSinceEpoch}';

      try {
        final result = await mermaid
            .callMethod<JSPromise<JSObject>>(
              'render'.toJS,
              <Object?>[renderId.toJS, source.toJS].jsify(),
            )
            .toDart;
        final svg = result.getProperty<JSString>('svg'.toJS).toDart;
        node.innerHTML = svg.toJS;
        node.dataset['rendered'] = 'true';
      } catch (_) {
        node.innerHTML = _fallbackMarkup(source).toJS;
        node.dataset['rendered'] = 'true';
      }
    }
  }

  String _fallbackMarkup(String source) {
    final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(source);
    return '<pre class="mermaid-fallback"><code>$escaped</code></pre>';
  }
}
