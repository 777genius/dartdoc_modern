// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dartdoc_vitepress/src/dartdoc_options.dart';
import 'package:dartdoc_vitepress/src/generator/core/path_utils.dart'
    show sanitizeAnchor;
import 'package:dartdoc_vitepress/src/logging.dart';
import 'package:dartdoc_vitepress/src/model/model_element.dart';
import 'package:dartdoc_vitepress/src/model/package_graph.dart';
import 'package:dartdoc_vitepress/src/runtime_stats.dart';
import 'package:dartdoc_vitepress/src/warnings.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as path;

enum MarkdownAnchorStrategy {
  vitepress,
  jaspr,
}

/// Validates generated markdown-first sites such as VitePress and Jaspr.
///
/// The HTML validator walks generated `index.html` files, which does not fit
/// markdown-first outputs. This validator instead checks that generated routes,
/// anchors, and navigation links resolve against the markdown pages actually
/// written during the generation run.
class MarkdownValidator {
  MarkdownValidator(
    this._packageGraph,
    this._config,
    String origin,
    this._writtenFiles,
    StreamController<String> onCheckProgress, {
    MarkdownAnchorStrategy anchorStrategy = MarkdownAnchorStrategy.vitepress,
  })   : _origin = path.normalize(origin),
        _onCheckProgress = onCheckProgress,
        _anchorStrategy = anchorStrategy,
        _hrefs = _packageGraph.allHrefs;

  final PackageGraph _packageGraph;
  final DartdocOptionContext _config;
  final String _origin;
  final Set<String> _writtenFiles;
  final StreamController<String> _onCheckProgress;
  final Map<String, Set<ModelElement>> _hrefs;
  final MarkdownAnchorStrategy _anchorStrategy;

  final Map<String, String> _routeToMarkdownPath = {};
  final Map<String, Set<String>> _anchorsByRoute = {};
  final Set<String> _markdownFiles = {};

  static final _frontMatterFence = RegExp(r'^---\s*$');
  static final _fencedCodeStart = RegExp(r'^\s*(```|~~~)');
  static final _headingPattern = RegExp(r'^\s{0,3}#{1,6}\s+(.*?)\s*$');
  static final _explicitHeadingAnchor = RegExp(r'\s+\{#([A-Za-z0-9:_\-.]+)\}\s*$');
  static final _htmlIdPattern =
      RegExp(r"""<[A-Za-z][^>]*\sid=['"]([^'"]+)['"][^>]*>""");
  static final _markdownLinkPattern = RegExp(r'!?\[[^\]]*\]\(([^)\n]+)\)');
  static final _htmlHrefOrSrcPattern =
      RegExp(r'''(?:href|src)=["']([^"'#][^"']*|#[^"']+)["']''');
  static final _sidebarLinkPattern = RegExp(r'''link:\s*["']([^"']+)["']''');
  static final _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');

  void validateLinks() {
    logInfo('Validating markdown links...');
    runtimeStats.resetAccumulators({
      'readCountForMarkdownValidation',
    });

    _indexMarkdownFiles();
    _validateMarkdownPages();
    _validateNavigationFiles();
  }

  void _indexMarkdownFiles() {
    final markdownFiles = _writtenFiles
        .where((file) => file.endsWith('.md'))
        .where(_isGeneratedMarkdownPage)
        .toList()
      ..sort();

    for (final relativePath in markdownFiles) {
      _markdownFiles.add(relativePath);
      final content = _readOutput(relativePath);
      final route = _routeFromMarkdownPath(relativePath);
      _routeToMarkdownPath[route] = relativePath;
      _anchorsByRoute[route] = _extractAnchors(content);
    }
  }

  void _validateMarkdownPages() {
    final markdownFiles = _markdownFiles.toList()..sort();
    for (final relativePath in markdownFiles) {
      if (!_isUserAuthoredMarkdownPage(relativePath)) {
        _onCheckProgress.add(relativePath);
        continue;
      }

      final content = _readOutput(relativePath);
      final route = _routeFromMarkdownPath(relativePath);
      final links = _extractLinks(content);
      for (final destination in links) {
        _validateDestination(
          destination,
          referredFrom: relativePath,
          currentRoute: route,
          currentMarkdownPath: relativePath,
        );
      }
      _onCheckProgress.add(relativePath);
    }
  }

  void _validateNavigationFiles() {
    final navigationFiles = _writtenFiles
        .where((file) =>
            file.endsWith('sidebar.ts') ||
            file.endsWith('sidebar.dart') ||
            file.endsWith('guide-sidebar.ts') ||
            file.endsWith('api-sidebar.ts'))
        .toList()
      ..sort();

    for (final relativePath in navigationFiles) {
      final content = _readOutput(relativePath);
      for (final match in _sidebarLinkPattern.allMatches(content)) {
        final destination = match.group(1);
        if (destination == null || destination.isEmpty) continue;
        _validateDestination(
          destination,
          referredFrom: relativePath,
        );
      }
      _onCheckProgress.add(relativePath);
    }
  }

  void _validateDestination(
    String rawDestination, {
    required String referredFrom,
    String? currentRoute,
    String? currentMarkdownPath,
  }) {
    final destination = _normalizeLinkDestination(rawDestination);
    if (destination.isEmpty || _isExternal(destination)) {
      return;
    }

    final fragmentIndex = destination.indexOf('#');
    final pathPart =
        fragmentIndex == -1 ? destination : destination.substring(0, fragmentIndex);
    final fragment =
        fragmentIndex == -1 ? null : destination.substring(fragmentIndex + 1);

    if (pathPart.isEmpty) {
      if (currentRoute == null || fragment == null || fragment.isEmpty) return;
      _validateAnchor(
        currentRoute,
        fragment,
        referredFrom: referredFrom,
      );
      return;
    }

    if (pathPart.startsWith('/')) {
      if (_assetExists(pathPart) || _validateRoute(pathPart, referredFrom: referredFrom)) {
        if (fragment != null && fragment.isNotEmpty) {
          _validateAnchor(
            pathPart,
            fragment,
            referredFrom: referredFrom,
          );
        }
      }
      return;
    }

    if (!_looksLikeRoutePath(pathPart)) {
      return;
    }

    final resolved = _resolveRelativeDestination(
      pathPart,
      currentMarkdownPath: currentMarkdownPath,
    );

    if (resolved == null) {
      _warn(PackageWarning.brokenLink, destination, referredFrom: referredFrom);
      return;
    }

    if (resolved.isAssetPath) {
      return;
    }

    if (_validateRoute(resolved.route!, referredFrom: referredFrom) &&
        fragment != null &&
        fragment.isNotEmpty) {
      _validateAnchor(
        resolved.route!,
        fragment,
        referredFrom: referredFrom,
      );
    }
  }

  bool _validateRoute(String route, {required String referredFrom}) {
    final normalizedRoute = _normalizeRoute(route);
    if (_routeToMarkdownPath.containsKey(normalizedRoute)) {
      return true;
    }
    _warn(PackageWarning.brokenLink, normalizedRoute, referredFrom: referredFrom);
    return false;
  }

  void _validateAnchor(
    String route,
    String anchor, {
    required String referredFrom,
  }) {
    final normalizedRoute = _normalizeRoute(route);
    final anchors = _anchorsByRoute[normalizedRoute];
    if (anchors == null || !anchors.contains(anchor)) {
      _warn(
        PackageWarning.brokenLink,
        '$normalizedRoute#$anchor',
        referredFrom: referredFrom,
      );
    }
  }

  _ResolvedMarkdownDestination? _resolveRelativeDestination(
    String destination, {
    String? currentMarkdownPath,
  }) {
    if (currentMarkdownPath == null) {
      return null;
    }

    final currentDir = path.posix.dirname(currentMarkdownPath);
    final relativeFile = path.posix.normalize(
      path.posix.join(currentDir, destination),
    );
    final extension = path.posix.extension(relativeFile);

    if (extension == '.md') {
      if (_markdownFiles.contains(relativeFile)) {
        return _ResolvedMarkdownDestination.route(
          _routeFromMarkdownPath(relativeFile),
        );
      }
      return null;
    }

    if (extension.isNotEmpty && _outputFileExists(relativeFile)) {
      return const _ResolvedMarkdownDestination.asset();
    }

    final routeDir = _routeFromMarkdownDir(currentDir);
    final route = _normalizeRoute(path.posix.join(routeDir, destination));
    return _ResolvedMarkdownDestination.route(route);
  }

  Set<String> _extractAnchors(String content) {
    if (_anchorStrategy == MarkdownAnchorStrategy.jaspr) {
      return _extractJasprAnchors(content);
    }

    final anchors = <String>{};

    for (final line in _linesWithoutFrontMatterAndCode(content)) {
      for (final match in _htmlIdPattern.allMatches(line)) {
        final id = match.group(1);
        if (id != null && id.isNotEmpty) {
          anchors.add(id);
        }
      }

      final headingMatch = _headingPattern.firstMatch(line);
      if (headingMatch == null) continue;

      final rawHeading = headingMatch.group(1)!.trim();
      final explicitAnchor = _explicitHeadingAnchor.firstMatch(rawHeading);
      if (explicitAnchor != null) {
        anchors.add(explicitAnchor.group(1)!);
      } else {
        final headingText = _stripMarkdownFormatting(rawHeading);
        final generatedAnchor = sanitizeAnchor(headingText);
        if (generatedAnchor.isNotEmpty) {
          anchors.add(generatedAnchor);
        }
      }
    }

    return anchors;
  }

  Set<String> _extractJasprAnchors(String content) {
    final anchors = <String>{};

    for (final line in _linesWithoutFrontMatterAndCode(content)) {
      for (final match in _htmlIdPattern.allMatches(line)) {
        final id = match.group(1);
        if (id != null && id.isNotEmpty) {
          anchors.add(id);
        }
      }
    }

    final document = md.Document(extensionSet: md.ExtensionSet.gitHubWeb);
    final nodes = document.parse(content);

    void visit(md.Node node) {
      if (node is! md.Element) return;

      if (RegExp(r'^h[1-6]$').hasMatch(node.tag)) {
        final generatedId = node.generatedId;
        if (generatedId != null && generatedId.isNotEmpty) {
          anchors.add(generatedId);
        }
      }

      for (final child in node.children ?? const <md.Node>[]) {
        visit(child);
      }
    }

    for (final node in nodes) {
      visit(node);
    }

    return anchors;
  }

  Set<String> _extractLinks(String content) {
    final links = <String>{};
    final sanitized = _linesWithoutFrontMatterAndCode(content).join('\n');

    for (final match in _markdownLinkPattern.allMatches(sanitized)) {
      final destination = match.group(1);
      if (destination == null) continue;
      final normalized = _normalizeLinkDestination(destination);
      if (normalized.isNotEmpty) {
        links.add(normalized);
      }
    }

    for (final match in _htmlHrefOrSrcPattern.allMatches(sanitized)) {
      final destination = match.group(1);
      if (destination == null) continue;
      final normalized = _normalizeLinkDestination(destination);
      if (normalized.isNotEmpty) {
        links.add(normalized);
      }
    }

    return links;
  }

  Iterable<String> _linesWithoutFrontMatterAndCode(String content) sync* {
    var inFrontMatter = false;
    var frontMatterHandled = false;
    var inFence = false;

    for (final line in content.split('\n')) {
      if (!frontMatterHandled && _frontMatterFence.hasMatch(line.trim())) {
        inFrontMatter = !inFrontMatter;
        if (!inFrontMatter) {
          frontMatterHandled = true;
        }
        continue;
      }
      if (inFrontMatter) continue;

      if (_fencedCodeStart.hasMatch(line)) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;

      yield line;
    }
  }

  String _normalizeLinkDestination(String destination) {
    var normalized = destination.trim();
    if (normalized.isEmpty) return '';
    if (normalized.startsWith('<') && normalized.endsWith('>')) {
      normalized = normalized.substring(1, normalized.length - 1);
    }

    final titleSeparator = RegExp(r"""\s+['"]""").firstMatch(normalized);
    if (titleSeparator != null) {
      normalized = normalized.substring(0, titleSeparator.start);
    }

    final queryIndex = normalized.indexOf('?');
    if (queryIndex != -1) {
      final hashIndex = normalized.indexOf('#');
      if (hashIndex == -1 || queryIndex < hashIndex) {
        normalized = normalized.substring(0, queryIndex) +
            (hashIndex == -1 ? '' : normalized.substring(hashIndex));
      }
    }
    return normalized.trim();
  }

  bool _isExternal(String destination) {
    if (destination.startsWith('//')) return true;
    if (_schemePattern.hasMatch(destination)) return true;
    return false;
  }

  bool _looksLikeRoutePath(String destination) {
    return destination.startsWith('./') ||
        destination.startsWith('../') ||
        destination.contains('/');
  }

  String _routeFromMarkdownPath(String relativePath) {
    final withoutPrefix = relativePath.replaceFirst(RegExp(r'^content/'), '');
    final noExt = withoutPrefix.replaceFirst(RegExp(r'\.md$'), '');
    if (noExt == 'index') return '/';
    if (noExt.endsWith('/index')) {
      return '/${noExt.substring(0, noExt.length - '/index'.length)}';
    }
    return '/$noExt';
  }

  String _routeFromMarkdownDir(String relativeDir) {
    final withoutPrefix = relativeDir.replaceFirst(RegExp(r'^content/?'), '');
    if (withoutPrefix.isEmpty || withoutPrefix == '.') {
      return '/';
    }
    return '/$withoutPrefix';
  }

  String _normalizeRoute(String route) {
    if (route.isEmpty) return '/';
    var normalized = route;
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    normalized = path.posix.normalize(normalized);
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _stripMarkdownFormatting(String text) {
    var stripped = text.replaceAll(_explicitHeadingAnchor, '');
    stripped = stripped.replaceAll(RegExp(r'<[^>]+>'), ' ');
    stripped = stripped.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (match) => match.group(1) ?? '',
    );
    stripped = stripped.replaceAll(RegExp(r'[`*_~]'), '');
    stripped = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
    return stripped;
  }

  String _readOutput(String relativePath) {
    final file = _config.resourceProvider.getFile(
      path.normalize(path.join(_origin, relativePath)),
    );
    runtimeStats.incrementAccumulator('readCountForMarkdownValidation');
    return file.readAsStringSync();
  }

  bool _assetExists(String rootRelativePath) {
    final fullPath =
        path.normalize(path.join(_origin, rootRelativePath.substring(1)));
    return _config.resourceProvider.getFile(fullPath).exists;
  }

  bool _outputFileExists(String relativePath) {
    final fullPath = path.normalize(path.join(_origin, relativePath));
    return _config.resourceProvider.getFile(fullPath).exists;
  }

  void _warn(
    PackageWarning kind,
    String warnOn, {
    required String referredFrom,
  }) {
    final referredFromElements = <Warnable>{};
    final hrefReferredFrom = _hrefs[referredFrom];
    if (hrefReferredFrom != null) {
      referredFromElements.addAll(hrefReferredFrom);
    }

    final warnOnElements = _hrefs[warnOn];
    if (referredFromElements.any((e) => e.isCanonical)) {
      referredFromElements.removeWhere((e) => !e.isCanonical);
    }
    final warnOnElement = warnOnElements?.firstWhereOrNull((e) => e.isCanonical);

    _packageGraph.warnOnElement(
      warnOnElement,
      kind,
      message: warnOn,
      referredFrom: referredFromElements,
    );
  }

  bool _isGeneratedMarkdownPage(String relativePath) {
    final normalized = relativePath.replaceFirst(RegExp(r'^content/'), '');
    return normalized.startsWith('api/') ||
        normalized == 'api/index.md' ||
        normalized.startsWith('guide/') ||
        normalized.startsWith('topics/') ||
        normalized == 'index.md';
  }

  bool _isUserAuthoredMarkdownPage(String relativePath) {
    final normalized = relativePath.replaceFirst(RegExp(r'^content/'), '');
    return normalized.startsWith('guide/') || normalized.startsWith('topics/');
  }
}

class _ResolvedMarkdownDestination {
  const _ResolvedMarkdownDestination.route(this.route) : isAssetPath = false;
  const _ResolvedMarkdownDestination.asset()
      : route = null,
        isAssetPath = true;

  final String? route;
  final bool isAssetPath;
}
