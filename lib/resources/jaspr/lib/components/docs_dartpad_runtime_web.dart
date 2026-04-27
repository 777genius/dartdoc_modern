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
  final Expando<_ScrollPosition> _lockedScrollPositions = Expando();

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
        return;
      }

      final closeButton = target.closest('.dartpad-close');
      if (closeButton != null) {
        event.preventDefault();
        final root = closeButton.closest('[data-dartpad]');
        if (root is web.HTMLElement) {
          _closeDartPad(root);
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

        _restoreLockedScroll(root);
        _setLoading(root, false);
        contentWindow?.postMessage(
          {
            'type': 'sourceCode',
            'sourceCode': _decodeBase64(
              root.getAttribute('data-source-base64'),
            ),
          }.jsify(),
          event.origin.toJS,
        );
        _scheduleScrollRestore(root);
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
        if (root.getAttribute('data-run') == 'true') 'run': 'true',
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
    if (root.getAttribute('data-active') == 'true') return;

    _lockScrollPosition(root);
    final stage = root.querySelector('.dartpad-stage');
    if (stage is! web.HTMLElement) return;

    final height = root.getAttribute('data-height') ?? '';
    final iframe = web.HTMLIFrameElement()
      ..className = 'dartpad-iframe'
      ..setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-popups allow-forms',
      )
      ..setAttribute('allow', 'clipboard-write')
      ..style.height = '${height.isEmpty ? '400' : height}px'
      ..src = _buildDartPadUrl(root);

    _setLoading(root, true);
    stage.innerHTML = ''.toJS;
    stage.appendChild(iframe);
    final idle = root.querySelector('.dartpad-idle');
    final active = root.querySelector('.dartpad-active');
    idle?.setAttribute('hidden', 'hidden');
    active?.removeAttribute('hidden');
    root.dataset['active'] = 'true';
    _restoreLockedScroll(root);
    _scheduleScrollRestore(root);
  }

  void _closeDartPad(web.HTMLElement root) {
    final stage = root.querySelector('.dartpad-stage');
    final idle = root.querySelector('.dartpad-idle');
    final active = root.querySelector('.dartpad-active');

    if (stage is web.HTMLElement) {
      stage.innerHTML = ''.toJS;
    }

    _setLoading(root, false);
    active?.setAttribute('hidden', 'hidden');
    idle?.removeAttribute('hidden');
    root.removeAttribute('data-active');
    _lockedScrollPositions[root] = null;
  }

  void _setLoading(web.HTMLElement root, bool isLoading) {
    final loader = root.querySelector('.dartpad-loader');
    final label = root.querySelector('.dartpad-label');

    if (loader is web.HTMLElement) {
      if (isLoading) {
        loader.removeAttribute('hidden');
      } else {
        loader.setAttribute('hidden', 'hidden');
      }
    }

    if (label is web.HTMLElement) {
      label.textContent = isLoading ? 'Loading DartPad…' : 'DartPad';
    }
  }

  Future<void> _copyDartPad(
    web.HTMLElement root,
    web.HTMLElement button,
  ) async {
    try {
      await web.window.navigator.clipboard
          .writeText(_decodeBase64(root.getAttribute('data-source-base64')))
          .toDart;
      final labelNode = button.querySelector('.dartpad-btn-label');
      final label = labelNode is web.HTMLElement ? labelNode : button;
      final original = label.textContent;
      button.dataset['copyState'] = 'copied';
      label.textContent = 'Copied';
      Timer(const Duration(milliseconds: 1500), () {
        button.removeAttribute('data-copy-state');
        label.textContent = original;
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
        _setLoading(root, true);
        iframe.src = _buildDartPadUrl(root);
      }
    }
  }

  void _lockScrollPosition(web.HTMLElement root) {
    _lockedScrollPositions[root] = _ScrollPosition(
      web.window.scrollX,
      web.window.scrollY,
    );
  }

  void _restoreLockedScroll(web.HTMLElement root) {
    final position = _lockedScrollPositions[root];
    if (position == null) return;
    web.window.scrollTo(position.x.toJS, position.y);
  }

  void _scheduleScrollRestore(web.HTMLElement root) {
    for (final delay in const [
      Duration.zero,
      Duration(milliseconds: 32),
      Duration(milliseconds: 120),
      Duration(milliseconds: 260),
    ]) {
      Timer(delay, () {
        if (root.getAttribute('data-active') != 'true') return;
        _restoreLockedScroll(root);
      });
    }
  }
}

class _ScrollPosition {
  const _ScrollPosition(this.x, this.y);

  final num x;
  final num y;
}
