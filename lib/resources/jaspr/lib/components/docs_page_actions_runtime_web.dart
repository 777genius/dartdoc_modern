import 'dart:async';
import 'dart:js_interop';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

@client
class DocsPageActionsRuntime extends StatefulComponent {
  const DocsPageActionsRuntime({super.key});

  @override
  State<DocsPageActionsRuntime> createState() => _DocsPageActionsRuntimeState();
}

class _DocsPageActionsRuntimeState extends State<DocsPageActionsRuntime> {
  JSFunction? _clickListener;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _clickListener = ((web.Event event) {
      final target = event.target;
      if (target is! web.Element) return;

      final copyButton = target.closest('[data-docs-copy-link]');
      if (copyButton is! web.HTMLElement) return;

      event.preventDefault();
      unawaited(_copyPageLink(copyButton));
    }).toJS;
    web.document.addEventListener('click', _clickListener);
  }

  @override
  void dispose() {
    if (_clickListener != null) {
      web.document.removeEventListener('click', _clickListener);
      _clickListener = null;
    }
    super.dispose();
  }

  @override
  Component build(BuildContext context) => span(
    attributes: {'hidden': 'hidden', 'data-docs-page-actions-runtime': ''},
    const [],
  );

  Future<void> _copyPageLink(web.HTMLElement button) async {
    try {
      await web.window.navigator.clipboard
          .writeText(web.window.location.href)
          .toDart;
      button.dataset['copyState'] = 'copied';
      button.setAttribute('aria-label', 'Copied page link');
      button.setAttribute('title', 'Copied page link');
      Timer(const Duration(milliseconds: 1400), () {
        button.removeAttribute('data-copy-state');
        button.setAttribute('aria-label', 'Copy page link');
        button.setAttribute('title', 'Copy page link');
      });
    } catch (_) {}
  }
}
