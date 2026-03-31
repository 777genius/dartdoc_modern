import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:jaspr/dom.dart';
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
  Timer? _bootTimer;
  Timer? _themeTimer;
  String _theme = 'light';
  JSFunction? _navigationListener;
  int _bootAttempts = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _theme = _currentTheme();
    _bootTimer =
        Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      _bootAttempts++;
      final rendered = await _renderMermaid();
      if (rendered || _bootAttempts >= 24) {
        timer.cancel();
        _bootTimer = null;
      }
    });
    _navigationListener = ((web.Event _) {
      Timer(
          const Duration(milliseconds: 50), () => _renderMermaid(force: true));
    }).toJS;
    web.window.addEventListener('docs:navigation', _navigationListener);
    _themeTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final nextTheme = _currentTheme();
      if (nextTheme == _theme) return;
      _theme = nextTheme;
      _renderMermaid(force: true);
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    _themeTimer?.cancel();
    if (_navigationListener != null) {
      web.window.removeEventListener('docs:navigation', _navigationListener);
      _navigationListener = null;
    }
    super.dispose();
  }

  @override
  Component build(BuildContext context) => span(
        attributes: {
          'data-docs-mermaid-runtime': '',
          'hidden': 'hidden',
          'aria-hidden': 'true',
        },
        const [],
      );

  String _currentTheme() =>
      web.document.documentElement?.getAttribute('data-theme') == 'dark'
          ? 'dark'
          : 'light';

  Future<bool> _renderMermaid({bool force = false}) async {
    final mermaid = _mermaid;
    if (mermaid == null) return false;

    final nodes = web.document.querySelectorAll('.mermaid-diagram');
    if (nodes.length == 0) return true;

    mermaid.callMethod(
      'initialize'.toJS,
      <Object?>[
        {
          'startOnLoad': false,
          'theme': _currentTheme() == 'dark' ? 'dark' : 'default',
          'securityLevel': 'loose',
          'suppressErrorRendering': true,
        }.jsify(),
      ].jsify(),
    );

    var preparedAny = false;
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes.item(index);
      if (node is! web.HTMLElement) continue;
      if (!force && node.getAttribute('data-rendered') == 'true') continue;

      final source = node.getAttribute('data-source-base64');
      if (source == null || source.isEmpty) continue;
      final host = node.querySelector('[data-mermaid-host]');
      if (host is! web.HTMLElement) continue;

      final placeholder = node.querySelector('[data-mermaid-placeholder]');
      final fallback = node.querySelector('[data-mermaid-fallback]');
      if (placeholder is web.HTMLElement) {
        placeholder.hidden = false;
      }
      if (fallback is web.HTMLElement) {
        fallback.hidden = true;
      }

      host.hidden = false;
      host.setAttribute('aria-hidden', 'false');
      host.removeAttribute('data-processed');
      host.innerHTML = '';
      host.textContent = web.window.atob(source);
      node.setAttribute('data-rendered', 'false');
      node.setAttribute('data-mermaid-state', 'pending');
      preparedAny = true;
    }

    if (!preparedAny && !force) return true;

    try {
      await mermaid
          .callMethod<JSPromise<JSAny?>>(
            'run'.toJS,
            <Object?>[
              {
                'suppressErrors': true,
              }.jsify(),
            ].jsify(),
          )
          .toDart;
    } catch (_) {
      return false;
    }

    var renderedAny = false;
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes.item(index);
      if (node is! web.HTMLElement) continue;
      final host = node.querySelector('[data-mermaid-host]');
      if (host is! web.HTMLElement) continue;

      final placeholder = node.querySelector('[data-mermaid-placeholder]');
      final fallback = node.querySelector('[data-mermaid-fallback]');
      final rendered = host.querySelector('svg') != null;
      if (rendered) {
        node.setAttribute('data-rendered', 'true');
        node.setAttribute('data-mermaid-state', 'rendered');
        if (placeholder is web.HTMLElement) {
          placeholder.hidden = true;
        }
        if (fallback is web.HTMLElement) {
          fallback.hidden = true;
        }
        renderedAny = true;
      } else {
        node.setAttribute('data-rendered', 'false');
        node.setAttribute('data-mermaid-state', 'error');
        if (placeholder is web.HTMLElement) {
          placeholder.hidden = true;
        }
        if (fallback is web.HTMLElement) {
          fallback.hidden = false;
        }
        host.hidden = true;
        host.setAttribute('aria-hidden', 'true');
      }
    }

    return renderedAny;
  }
}
