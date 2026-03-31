import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

@client
class DocsDartPadRuntime extends StatefulComponent {
  const DocsDartPadRuntime({super.key});

  @override
  State<DocsDartPadRuntime> createState() => _DocsDartPadRuntimeState();
}

class _DocsDartPadRuntimeState extends State<DocsDartPadRuntime> {
  static const _allowedOrigins = {
    'https://dartpad.dev',
    'https://www.dartpad.dev',
    'https://dartpad.cn',
    'https://www.dartpad.cn',
  };

  JSFunction? _clickListener;
  JSFunction? _messageListener;
  Timer? _themeTimer;
  String _theme = 'light';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _theme = _currentTheme();
    _clickListener = ((web.Event event) {
      final target = event.target;
      if (target is! web.Element) return;

      final runButton = target.closest('.dartpad-run');
      if (runButton != null) {
        event.preventDefault();
        final root = runButton.closest('[data-dartpad]');
        if (root is web.HTMLElement) {
          _activateDartPad(root);
        }
        return;
      }

      final copyButton = target.closest('.dartpad-copy');
      if (copyButton != null) {
        event.preventDefault();
        final root = copyButton.closest('[data-dartpad]');
        if (root is web.HTMLElement && copyButton is web.HTMLElement) {
          unawaited(_copyDartPad(root, copyButton));
        }
      }
    }).toJS;
    web.document.addEventListener('click', _clickListener);

    _messageListener = ((web.Event event) {
      if (event is! web.MessageEvent) return;
      if (!_allowedOrigins.contains(event.origin)) return;

      final iframes = web.document.querySelectorAll('.dartpad-iframe');
      for (var index = 0; index < iframes.length; index++) {
        final candidate = iframes.item(index);
        if (candidate is! web.HTMLIFrameElement) continue;
        final contentWindow = candidate.contentWindow;
        if (contentWindow != event.source) continue;

        final root = candidate.closest('[data-dartpad]');
        if (root is! web.HTMLElement) return;

        contentWindow?.postMessage({
          'type': 'sourceCode',
          'sourceCode': _decodeBase64(root.dataset['sourceBase64']),
        }.jsify(), event.origin.toJS);
        return;
      }
    }).toJS;
    web.window.addEventListener('message', _messageListener);

    _themeTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final nextTheme = _currentTheme();
      if (nextTheme == _theme) return;
      _theme = nextTheme;
      _refreshActiveFrames();
    });
  }

  @override
  void dispose() {
    if (_clickListener != null) {
      web.document.removeEventListener('click', _clickListener);
      _clickListener = null;
    }
    if (_messageListener != null) {
      web.window.removeEventListener('message', _messageListener);
      _messageListener = null;
    }
    _themeTimer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) => Component.fragment(const []);

  String _currentTheme() =>
      web.document.documentElement?.getAttribute('data-theme') == 'dark'
          ? 'dark'
          : 'light';

  String _buildDartPadUrl(web.HTMLElement root) {
    final params = Uri(
      queryParameters: {
        'embed': 'true',
        'theme': _currentTheme(),
        if (root.dataset['run'] == 'true') 'run': 'true',
      },
    ).query;
    return 'https://dartpad.dev/?$params';
  }

  String _decodeBase64(String? value) {
    try {
      return utf8.decode(base64Decode(value ?? ''));
    } catch (_) {
      return value ?? '';
    }
  }

  void _activateDartPad(web.HTMLElement root) {
    if (root.dataset['active'] == 'true') return;

    final stage = root.querySelector('.dartpad-stage');
    if (stage is! web.HTMLElement) return;

    final height = root.dataset['height'];
    final iframe = web.HTMLIFrameElement()
      ..className = 'dartpad-iframe'
      ..setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-popups allow-forms',
      )
      ..setAttribute('allow', 'clipboard-write')
      ..style.height = '${height.isEmpty ? '400' : height}px'
      ..src = _buildDartPadUrl(root);

    stage.innerHTML = ''.toJS;
    stage.appendChild(iframe);
    root.dataset['active'] = 'true';
  }

  Future<void> _copyDartPad(
    web.HTMLElement root,
    web.HTMLElement button,
  ) async {
    try {
      await web.window.navigator.clipboard
          .writeText(_decodeBase64(root.dataset['sourceBase64']))
          .toDart;
      final original = button.textContent;
      button.textContent = 'Copied';
      Timer(const Duration(milliseconds: 1500), () {
        button.textContent = original;
      });
    } catch (_) {}
  }

  void _refreshActiveFrames() {
    final roots = web.document.querySelectorAll('[data-dartpad]');
    for (var index = 0; index < roots.length; index++) {
      final root = roots.item(index);
      if (root is! web.HTMLElement) continue;
      final iframe = root.querySelector('.dartpad-iframe');
      if (iframe is web.HTMLIFrameElement) {
        iframe.src = _buildDartPadUrl(root);
      }
    }
  }
}
