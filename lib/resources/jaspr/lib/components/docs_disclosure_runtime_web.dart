import 'dart:async';
import 'dart:js_interop';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

@client
class DocsDisclosureRuntime extends StatefulComponent {
  const DocsDisclosureRuntime({super.key});

  @override
  State<DocsDisclosureRuntime> createState() => _DocsDisclosureRuntimeState();
}

class _DocsDisclosureRuntimeState extends State<DocsDisclosureRuntime> {
  JSFunction? _clickListener;
  JSFunction? _navigationListener;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _enhanceAll();

    _clickListener = ((web.Event event) {
      _handleClick(event);
    }).toJS;
    _navigationListener = ((web.Event _) {
      Timer(const Duration(milliseconds: 50), _enhanceAll);
    }).toJS;

    web.document.addEventListener('click', _clickListener);
    web.window.addEventListener('docs:navigation', _navigationListener);
  }

  @override
  void dispose() {
    if (_clickListener != null) {
      web.document.removeEventListener('click', _clickListener);
      _clickListener = null;
    }
    if (_navigationListener != null) {
      web.window.removeEventListener('docs:navigation', _navigationListener);
      _navigationListener = null;
    }
    super.dispose();
  }

  @override
  Component build(BuildContext context) => span(
        attributes: {
          'data-docs-disclosure-runtime': '',
          'hidden': 'hidden',
          'aria-hidden': 'true',
        },
        const [],
      );

  void _enhanceAll() {
    final disclosures = web.document.querySelectorAll('.content details');
    for (var index = 0; index < disclosures.length; index++) {
      final node = disclosures.item(index);
      if (node is! web.HTMLDetailsElement) continue;
      if (!_isContentDisclosure(node)) continue;
      _enhanceDisclosure(node);
    }
  }

  bool _isContentDisclosure(web.HTMLDetailsElement details) {
    if (details.closest('.toc') != null) return false;
    return details.closest('.content') != null;
  }

  void _enhanceDisclosure(web.HTMLDetailsElement details) {
    if (details.hasAttribute('data-disclosure-enhanced')) {
      _syncDisclosureState(details);
      return;
    }

    final summary = _findSummary(details);
    if (summary == null) return;

    final body = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'docs-disclosure-body';
    final inner = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'docs-disclosure-inner';

    final toMove = <web.Node>[];
    for (web.Node? node = summary.nextSibling;
        node != null;
        node = summary.nextSibling) {
      toMove.add(node);
      summary.parentNode?.removeChild(node);
    }
    for (final node in toMove) {
      inner.append(node);
    }
    body.append(inner);
    details.append(body);

    details.setAttribute('data-disclosure-enhanced', 'true');
    details.classList.add('docs-disclosure');
    _syncDisclosureState(details);
  }

  web.HTMLElement? _findSummary(web.HTMLDetailsElement details) {
    for (web.Element? child = details.firstElementChild;
        child != null;
        child = child.nextElementSibling) {
      if (child is web.HTMLElement &&
          child.localName.toLowerCase() == 'summary') {
        return child;
      }
    }
    return null;
  }

  web.HTMLDivElement? _findBody(web.HTMLDetailsElement details) {
    for (web.Element? child = details.firstElementChild;
        child != null;
        child = child.nextElementSibling) {
      if (child is web.HTMLDivElement &&
          child.classList.contains('docs-disclosure-body')) {
        return child;
      }
    }
    return null;
  }

  web.HTMLDivElement? _findInner(web.HTMLDivElement body) {
    for (web.Element? child = body.firstElementChild;
        child != null;
        child = child.nextElementSibling) {
      if (child is web.HTMLDivElement &&
          child.classList.contains('docs-disclosure-inner')) {
        return child;
      }
    }
    return null;
  }

  void _syncDisclosureState(web.HTMLDetailsElement details) {
    final body = _findBody(details);
    if (body == null) return;

    if (details.open) {
      details.classList.add('is-open');
      details.classList.remove('is-closing');
      body.style.height = 'auto';
      body.style.opacity = '1';
      body.style.overflow = 'visible';
    } else {
      details.classList.remove('is-open');
      details.classList.remove('is-closing');
      body.style.height = '0px';
      body.style.opacity = '0';
      body.style.overflow = 'hidden';
    }
  }

  void _handleClick(web.Event event) {
    final target = event.target;
    if (target is! web.Element) return;

    final summary = target.closest('summary');
    if (summary is! web.HTMLElement) return;
    final parent = summary.parentElement;
    if (parent is! web.HTMLDetailsElement || !_isContentDisclosure(parent)) {
      return;
    }

    event.preventDefault();
    _toggleDisclosure(parent);
  }

  void _toggleDisclosure(web.HTMLDetailsElement details) {
    final body = _findBody(details);
    final inner = body != null ? _findInner(body) : null;
    if (body == null || inner == null) return;

    if (_prefersReducedMotion()) {
      details.open = !details.open;
      _syncDisclosureState(details);
      return;
    }

    if (details.classList.contains('is-animating')) return;
    details.classList.add('is-animating');

    if (details.open) {
      _collapse(details, body, inner);
    } else {
      _expand(details, body, inner);
    }
  }

  bool _prefersReducedMotion() {
    return web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }

  void _expand(
    web.HTMLDetailsElement details,
    web.HTMLDivElement body,
    web.HTMLDivElement inner,
  ) {
    details.open = true;
    details.classList.add('is-opening');
    details.classList.remove('is-closing');

    body.style.overflow = 'hidden';
    body.style.height = '0px';
    body.style.opacity = '0';

    final targetHeight = inner.scrollHeight;
    body.getBoundingClientRect();

    late JSFunction onEnd;
    onEnd = ((web.Event _) {
      body.removeEventListener('transitionend', onEnd);
      details.classList.remove('is-opening');
      details.classList.remove('is-animating');
      details.classList.add('is-open');
      body.style.height = 'auto';
      body.style.opacity = '1';
      body.style.overflow = 'visible';
    }).toJS;

    body.addEventListener('transitionend', onEnd);
    body.style.height = '${targetHeight}px';
    body.style.opacity = '1';
  }

  void _collapse(
    web.HTMLDetailsElement details,
    web.HTMLDivElement body,
    web.HTMLDivElement inner,
  ) {
    details.classList.remove('is-opening');
    details.classList.add('is-closing');
    details.classList.remove('is-open');

    final startHeight = body.getBoundingClientRect().height;
    if (startHeight <= 0) {
      details.open = false;
      details.classList.remove('is-closing');
      details.classList.remove('is-animating');
      _syncDisclosureState(details);
      return;
    }

    body.style.overflow = 'hidden';
    body.style.height = '${startHeight}px';
    body.style.opacity = '1';
    body.getBoundingClientRect();

    late JSFunction onEnd;
    onEnd = ((web.Event _) {
      body.removeEventListener('transitionend', onEnd);
      details.open = false;
      details.classList.remove('is-closing');
      details.classList.remove('is-animating');
      body.style.height = '0px';
      body.style.opacity = '0';
      body.style.overflow = 'hidden';
    }).toJS;

    body.addEventListener('transitionend', onEnd);
    final _ = inner.scrollHeight;
    body.style.height = '0px';
    body.style.opacity = '0';
  }
}
