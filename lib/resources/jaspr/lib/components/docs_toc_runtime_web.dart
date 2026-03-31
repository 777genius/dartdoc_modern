import 'dart:async';
import 'dart:js_interop';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

@client
class DocsTocRuntime extends StatefulComponent {
  const DocsTocRuntime({super.key});

  @override
  State<DocsTocRuntime> createState() => _DocsTocRuntimeState();
}

class _DocsTocRuntimeState extends State<DocsTocRuntime> {
  JSFunction? _scrollListener;
  JSFunction? _resizeListener;
  JSFunction? _navigationListener;
  Timer? _updateTimer;
  String? _lastActiveId;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _scrollListener = ((web.Event _) => _scheduleUpdate()).toJS;
    _resizeListener = ((web.Event _) => _scheduleUpdate()).toJS;
    _navigationListener = ((web.Event _) {
      Timer(const Duration(milliseconds: 50), _updateActiveSection);
    }).toJS;

    web.window.addEventListener('scroll', _scrollListener);
    web.window.addEventListener('resize', _resizeListener);
    web.window.addEventListener('docs:navigation', _navigationListener);

    Timer(const Duration(milliseconds: 50), _updateActiveSection);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    if (_scrollListener != null) {
      web.window.removeEventListener('scroll', _scrollListener);
      _scrollListener = null;
    }
    if (_resizeListener != null) {
      web.window.removeEventListener('resize', _resizeListener);
      _resizeListener = null;
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
          'data-docs-toc-runtime': '',
          'hidden': 'hidden',
          'aria-hidden': 'true',
        },
        const [],
      );

  void _scheduleUpdate() {
    _updateTimer?.cancel();
    _updateTimer =
        Timer(const Duration(milliseconds: 60), _updateActiveSection);
  }

  void _updateActiveSection() {
    final tocLinks = web.document.querySelectorAll('.toc .toc-link');
    if (tocLinks.length == 0) return;

    final targets = <_TocTarget>[];
    for (var index = 0; index < tocLinks.length; index++) {
      final node = tocLinks.item(index);
      if (node is! web.HTMLElement) continue;
      final id = node.getAttribute('data-toc-link') ?? '';
      if (id.isEmpty) continue;
      final heading = web.document.getElementById(id);
      if (heading == null) continue;
      targets.add(_TocTarget(id: id, link: node, heading: heading));
    }

    if (targets.isEmpty) return;

    final offset = _offsetForViewport();
    final active = _resolveActiveTarget(targets, offset);

    for (final target in targets) {
      final isActive = identical(target, active);
      if (isActive) {
        target.link.classList.add('active');
      } else {
        target.link.classList.remove('active');
      }
    }

    final detailsNodes = web.document.querySelectorAll('.toc details');
    for (var index = 0; index < detailsNodes.length; index++) {
      final node = detailsNodes.item(index);
      if (node is! web.HTMLDetailsElement) continue;
      node.open = node.querySelector('.toc-link.active') != null;
    }

    _openAncestorDetails(active.link);
    _ensureLinkVisible(active.link, active.id);
  }

  double _offsetForViewport() {
    final width = web.window.innerWidth.toDouble();
    final header = web.document.querySelector('.header-container');
    final headerHeight = header is web.HTMLElement
        ? header.getBoundingClientRect().height
        : 0.0;

    final breathingRoom = width < 960
        ? 20.0
        : width < 1280
            ? 28.0
            : 36.0;
    return headerHeight + breathingRoom;
  }

  void _openAncestorDetails(web.HTMLElement link) {
    web.Element? current = link.parentElement;
    while (current != null) {
      if (current is web.HTMLDetailsElement) {
        current.open = true;
      }
      current = current.parentElement;
    }
  }

  void _ensureLinkVisible(web.HTMLElement link, String activeId) {
    if (_lastActiveId == activeId) return;
    _lastActiveId = activeId;

    final container = link.closest('.toc > div');
    if (container is! web.HTMLElement) return;

    final targetScroll =
        link.offsetTop - ((container.clientHeight - link.clientHeight) / 2);
    final clampedScroll = targetScroll.clamp(0, container.scrollHeight.toDouble());
    if ((container.scrollTop - clampedScroll).abs() < 8) return;
    container.scrollTop = clampedScroll;
  }

  _TocTarget _resolveActiveTarget(List<_TocTarget> targets, double offset) {
    for (var index = 0; index < targets.length; index++) {
      final current = targets[index];
      final currentTop = current.heading.getBoundingClientRect().top;
      final nextTop = index + 1 < targets.length
          ? targets[index + 1].heading.getBoundingClientRect().top
          : double.infinity;

      if (currentTop - offset <= 0 && nextTop - offset > 0) {
        return current;
      }
    }

    final firstTop = targets.first.heading.getBoundingClientRect().top;
    if (firstTop - offset > 0) {
      return targets.first;
    }

    return targets.last;
  }
}

class _TocTarget {
  const _TocTarget({
    required this.id,
    required this.link,
    required this.heading,
  });

  final String id;
  final web.HTMLElement link;
  final web.Element heading;
}
