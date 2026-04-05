import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

import '../docs_base.dart';
import 'docs_navigation_runtime.dart';
import 'docs_nav_link.dart';
import 'docs_disclosure_runtime.dart';
import 'docs_lightbox_runtime.dart';
import 'docs_mermaid_runtime.dart';
import 'docs_sidebar_toggle_runtime.dart';
import 'docs_toc_runtime.dart';

@client
class DocsSearchShell extends StatefulComponent {
  const DocsSearchShell({super.key});

  @override
  State<DocsSearchShell> createState() => _DocsSearchShellState();
}

class _DocsSearchShellState extends State<DocsSearchShell> {
  static const _defaultStatus = 'Type at least 2 characters to search.';
  static const _manifestCacheKeyPrefix = 'docs.search.manifest.v5:';
  static const _pagesCacheKeyPrefix = 'docs.search.pages.v2:';
  static const _sectionsCachePrefix = 'docs.search.sections.v2:';

  Timer? _searchDebounceTimer;
  Timer? _warmSectionsTimer;

  bool _isOpen = false;
  bool _isApplePlatform = false;
  String _query = '';
  String _status = _defaultStatus;
  List<_SearchEntry> _results = const [];
  int _selectedIndex = -1;
  int _latestQueryToken = 0;
  web.HTMLElement? _lastFocusedBeforeOpen;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _isApplePlatform = _detectApplePlatform();
    Timer.run(_mountOverlayToBody);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _warmSectionsTimer?.cancel();
    if (kIsWeb) {
      web.window.document.body?.classList.remove('search-open');
    }
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final results = _results;
    final isBusy =
        _status == 'Loading search...' ||
        _status == 'Searching...' ||
        _status == 'Searching sections...' ||
        _status == 'Searching pages and sections...' ||
        _status == 'Deepening search...' ||
        _status == 'Searching full section content...';
    final searchState = switch (_status) {
      'Search is unavailable.' => 'error',
      'No results found.' => 'empty',
      _ when isBusy => 'loading',
      _ => results.isEmpty ? 'idle' : 'results',
    };

    return Component.fragment([
      const DocsNavigationRuntime(),
      const DocsDisclosureRuntime(),
      const DocsLightboxRuntime(),
      const DocsMermaidRuntime(),
      const DocsSidebarToggleRuntime(),
      const DocsTocRuntime(),
      div(classes: 'header-search-shell', [
        button(
          classes: 'search-launcher',
          attributes: {
            'type': 'button',
            'data-docs-search-launcher': '',
            'aria-label': 'Open documentation search',
          },
          events: {
            ...events(onClick: _openSearch),
            'mouseenter': (_) => _warmSearch(),
            'focus': (_) => _warmSearch(),
          },
          [
            span(classes: 'search-launcher-label', [
              Component.text('Search docs'),
            ]),
            span(classes: 'search-launcher-shortcut', [
              Component.text(_isApplePlatform ? '⌘ K' : 'Ctrl K'),
            ]),
          ],
        ),
      ]),
      div(
        classes: 'docs-search-overlay',
        attributes: {
          if (!_isOpen) 'hidden': 'hidden',
          'data-docs-search-overlay': '',
          'data-search-state': searchState,
          'role': 'dialog',
          'aria-modal': 'true',
          'aria-labelledby': 'docs-search-title',
        },
        events: {'keydown': _handlePanelKeyDown},
        [
          div(
            classes: 'docs-search-backdrop',
            events: events(onClick: _closeSearch),
            [],
          ),
          div(classes: 'docs-search-panel', [
            div(classes: 'docs-search-header', [
              div(
                classes: 'docs-search-heading',
                attributes: {'id': 'docs-search-title'},
                [Component.text('Search Documentation')],
              ),
              input(
                type: InputType.search,
                classes: 'docs-search-input',
                value: _query,
                attributes: {
                  'data-search-input': '',
                  'id': 'docs-search-input',
                  'name': 'q',
                  'placeholder': 'Search API and guides',
                  'autocomplete': 'off',
                  'spellcheck': 'false',
                  'aria-label': 'Search documentation',
                },
                events: {
                  ...events<String>(
                    onInput: (value) {
                      _query = value;
                      _scheduleSearch(value);
                    },
                  ),
                  'focus': (_) => _warmSearch(),
                },
              ),
              button(
                classes: 'docs-search-close',
                attributes: {
                  'type': 'button',
                  'data-docs-search-close': '',
                  'aria-label': 'Close documentation search',
                },
                events: events(onClick: _closeSearch),
                [Component.text('Esc')],
              ),
            ]),
            div(
              classes: 'docs-search-status',
              attributes: {
                'aria-live': 'polite',
                'data-search-state': searchState,
              },
              [Component.text(_status)],
            ),
            div(
              classes: 'docs-search-results',
              attributes: {
                'role': 'listbox',
                'aria-label': 'Search results',
                'data-search-state': searchState,
              },
              [
                if (results.isEmpty)
                  div(classes: 'docs-search-empty-state', [
                    div(classes: 'docs-search-empty-icon', [
                      Component.text(switch (searchState) {
                        'loading' => '…',
                        'error' => '!',
                        'empty' => '0',
                        _ => '⌕',
                      }),
                    ]),
                    div(classes: 'docs-search-empty-copy', [
                      div(classes: 'docs-search-empty-title', [
                        Component.text(switch (searchState) {
                          'loading' => 'Preparing results',
                          'error' => 'Search unavailable',
                          'empty' => 'No matching pages',
                          _ => 'Search the docs',
                        }),
                      ]),
                      div(classes: 'docs-search-empty-text', [
                        Component.text(switch (searchState) {
                          'loading' =>
                            'Loading indexed pages and sections for this query.',
                          'error' =>
                            'The search index could not be loaded in this session.',
                          'empty' =>
                            'Try a shorter query, a type name, or a guide title.',
                          _ =>
                            'Search across API pages, section headings, and guides.',
                        }),
                      ]),
                    ]),
                  ]),
                for (var index = 0; index < results.length; index++)
                  _buildResultCard(results[index], index),
              ],
            ),
            div(classes: 'docs-search-footer', [
              div(classes: 'docs-search-hints', [
                span(classes: 'docs-search-key', [Component.text('↑')]),
                span(classes: 'docs-search-key', [Component.text('↓')]),
                span(classes: 'docs-search-hint-label', [
                  Component.text('Move'),
                ]),
                span(classes: 'docs-search-key', [Component.text('Enter')]),
                span(classes: 'docs-search-hint-label', [
                  Component.text('Open'),
                ]),
                span(classes: 'docs-search-key', [Component.text('Esc')]),
                span(classes: 'docs-search-hint-label', [
                  Component.text('Close'),
                ]),
              ]),
              span(classes: 'docs-search-footnote', [
                Component.text('API pages, sections, and guides'),
              ]),
            ]),
          ]),
        ],
      ),
    ]);
  }

  Component _buildResultCard(_SearchEntry entry, int index) {
    final selected = index == _selectedIndex;
    final kindLabel = entry.section.isNotEmpty
        ? 'Section'
        : switch (entry.kind) {
            'api' => 'API',
            'guide' => 'Guide',
            _ => 'Page',
          };
    final resultClass = [
      'docs-search-result',
      if (entry.section.isNotEmpty)
        'docs-search-result-section'
      else
        'docs-search-result-page',
      if (selected) 'active',
    ].join(' ');
    final kindClass = entry.section.isNotEmpty
        ? 'docs-search-kind docs-search-kind-section'
        : 'docs-search-kind docs-search-kind-${entry.kind}';

    return DocsNavLink(
      to: entry.url,
      classes: resultClass,
      attributes: {'role': 'option', if (selected) 'aria-selected': 'true'},
      onNavigate: _closeSearch,
      onMouseEnter: (_) {
        if (_selectedIndex == index) return;
        setState(() {
          _selectedIndex = index;
        });
      },
      children: [
        div(classes: 'docs-search-meta', [
          div(classes: 'docs-search-topline', [
            div(classes: kindClass, [Component.text(kindLabel)]),
            div(classes: 'docs-search-url', [Component.text(entry.url)]),
          ]),
          div(classes: 'docs-search-title', [
            ..._buildHighlightedText(entry.title, _tokens),
            if (entry.section.isNotEmpty)
              span(classes: 'docs-search-section', [
                ..._buildHighlightedText(' ${entry.section}', _tokens),
              ]),
          ]),
          div(
            classes: 'docs-search-summary',
            _buildHighlightedText(_buildExcerpt(entry, _tokens), _tokens),
          ),
        ]),
      ],
    );
  }

  List<String> get _tokens => _tokenize(_query);

  bool _detectApplePlatform() {
    final platform = web.window.navigator.platform;
    return platform.contains('Mac') ||
        platform.contains('iPhone') ||
        platform.contains('iPad') ||
        platform.contains('iPod');
  }

  void _handlePanelKeyDown(web.Event event) {
    if (event is! web.KeyboardEvent || !_isOpen) return;

    if (event.key == 'Escape') {
      event.preventDefault();
      _closeSearch();
      return;
    }

    if (event.key == 'Tab') {
      final focusables = _focusableNodesWithin(_overlayElement);
      if (focusables.isEmpty) return;

      final activeElement = web.window.document.activeElement;
      final currentIndex = activeElement is web.HTMLElement
          ? focusables.indexOf(activeElement)
          : -1;
      final nextIndex = event.shiftKey
          ? (currentIndex <= 0 ? focusables.length - 1 : currentIndex - 1)
          : (currentIndex == -1 || currentIndex >= focusables.length - 1
                ? 0
                : currentIndex + 1);
      event.preventDefault();
      focusables[nextIndex].focus();
      return;
    }

    if (event.key == 'ArrowDown' || event.key == 'ArrowUp') {
      if (_results.isEmpty) return;
      event.preventDefault();
      final delta = event.key == 'ArrowDown' ? 1 : -1;
      final startIndex = _selectedIndex == -1
          ? (delta > 0 ? -1 : 0)
          : _selectedIndex;
      final nextIndex =
          (startIndex + delta + _results.length) % _results.length;
      _setActiveSearchResult(nextIndex);
      return;
    }

    if (event.key == 'Enter' &&
        _selectedIndex >= 0 &&
        _selectedIndex < _results.length) {
      event.preventDefault();
      final results = web.window.document.querySelectorAll(
        '.docs-search-result',
      );
      if (_selectedIndex < results.length) {
        final node = results.item(_selectedIndex);
        if (node is web.HTMLElement) {
          node.click();
          return;
        }
      }
      _navigateTo(_results[_selectedIndex].url);
    }
  }

  web.HTMLElement? get _overlayElement {
    final element = web.window.document.querySelector('.docs-search-overlay');
    return element is web.HTMLElement ? element : null;
  }

  web.HTMLInputElement? get _inputElement {
    final element = web.window.document.querySelector('[data-search-input]');
    return element is web.HTMLInputElement ? element : null;
  }

  void _mountOverlayToBody() {
    if (!kIsWeb) return;
    final overlay = _overlayElement;
    final body = web.window.document.body;
    if (overlay == null || body == null || overlay.parentElement == body) {
      return;
    }
    body.append(overlay);
  }

  List<web.HTMLElement> _focusableNodesWithin(web.Element? root) {
    if (root == null) return const [];
    final nodes = root.querySelectorAll(
      'a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
    );
    final elements = <web.HTMLElement>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes.item(index);
      if (node is web.HTMLElement && !node.hasAttribute('hidden')) {
        elements.add(node);
      }
    }
    return elements;
  }

  void _openSearch([String initialValue = '']) {
    _mountOverlayToBody();
    if (kIsWeb) {
      final active = web.window.document.activeElement;
      if (active is web.HTMLElement) {
        _lastFocusedBeforeOpen = active;
      }
      web.window.document.body?.classList.add('search-open');
    }

    setState(() {
      _isOpen = true;
      _query = initialValue;
      _status = 'Loading search...';
      _selectedIndex = -1;
      if (initialValue.isEmpty) {
        _results = const [];
      }
    });

    unawaited(_primeSearch(initialValue));

    Timer.run(() {
      _mountOverlayToBody();
      _inputElement?.focus();
    });
  }

  void _closeSearch() {
    _searchDebounceTimer?.cancel();
    _warmSectionsTimer?.cancel();
    if (kIsWeb) {
      web.window.document.body?.classList.remove('search-open');
    }
    setState(() {
      _isOpen = false;
      _selectedIndex = -1;
    });
    _lastFocusedBeforeOpen?.focus();
    _lastFocusedBeforeOpen = null;
  }

  void _scheduleSearch(String query, {bool immediate = false}) {
    if (!mounted) return;
    _searchDebounceTimer?.cancel();

    if (immediate) {
      unawaited(_runSearch(query));
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 70), () {
      unawaited(_runSearch(query));
    });
  }

  void _warmSearch() {
    unawaited(_warmSearchAsync());
  }

  void _scheduleSectionsWarmup() {
    _warmSectionsTimer?.cancel();
    _warmSectionsTimer = Timer(const Duration(milliseconds: 180), () {
      if (_DocsSearchCache.sectionsReady ||
          _DocsSearchCache.loadingSections != null) {
        return;
      }
      unawaited(_warmSectionsAsync());
    });
  }

  Future<void> _primeSearch(String initialValue) async {
    try {
      await _ensurePagesReady();
      _scheduleSectionsWarmup();
      if (!mounted || !_isOpen) return;

      final activeQuery = _query.trim();
      if (activeQuery.isNotEmpty) {
        _scheduleSearch(activeQuery, immediate: true);
        return;
      }

      if (initialValue.trim().isNotEmpty) {
        _scheduleSearch(initialValue, immediate: true);
        return;
      }

      setState(() {
        _status = _defaultStatus;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Search is unavailable.';
        _results = const [];
        _selectedIndex = -1;
      });
    }
  }

  Future<void> _warmSearchAsync() async {
    try {
      await _ensurePagesReady();
      _scheduleSectionsWarmup();
    } catch (_) {}
  }

  Future<void> _warmSectionsAsync() async {
    try {
      await _ensureSectionsReady();
    } catch (_) {}
  }

  Future<void> _runSearch(String query) async {
    final queryToken = ++_latestQueryToken;
    final tokens = _tokenize(query);

    if (tokens.isEmpty) {
      if (!mounted || queryToken != _latestQueryToken) return;
      setState(() {
        _query = query;
        _results = const [];
        _status = _defaultStatus;
        _selectedIndex = -1;
      });
      return;
    }

    if (mounted && queryToken == _latestQueryToken) {
      setState(() {
        _query = query;
        _status = 'Searching...';
      });
    }

    try {
      final pageEntries = await _ensurePagesReady();
      if (!mounted || queryToken != _latestQueryToken) return;

      final phrase = _normalizeSearchText(query);
      final rankedPages =
          pageEntries
              .map(
                (entry) => _RankedSearchEntry(
                  entry: entry,
                  score: _scoreEntry(entry, tokens, phrase),
                ),
              )
              .where((item) => item.score > 0)
              .toList()
            ..sort((a, b) => b.score.compareTo(a.score));

      var ranked = rankedPages.take(20).toList();
      final shouldLoadSections = phrase.length >= 3 || rankedPages.length < 8;

      if (shouldLoadSections) {
        if (!mounted || queryToken != _latestQueryToken) return;
        setState(() {
          _status = rankedPages.isNotEmpty
              ? 'Searching sections...'
              : 'Searching pages and sections...';
        });

        final sectionEntries = await _ensureSectionsReady();
        if (!mounted || queryToken != _latestQueryToken) return;

        final rankedSections =
            sectionEntries
                .map(
                  (entry) => _RankedSearchEntry(
                    entry: entry,
                    score: _scoreEntry(entry, tokens, phrase),
                  ),
                )
                .where((item) => item.score > 0)
                .toList()
              ..sort((a, b) => b.score.compareTo(a.score));

        ranked = [...rankedPages.take(20), ...rankedSections.take(20)]
          ..sort((a, b) => b.score.compareTo(a.score));
        if (ranked.length > 20) ranked = ranked.take(20).toList();

        final shouldLoadSectionContent =
            !_DocsSearchCache.sectionsContentReady &&
            (phrase.length >= 4 || ranked.length < 8);
        if (shouldLoadSectionContent) {
          if (!mounted || queryToken != _latestQueryToken) return;
          setState(() {
            _status = ranked.isNotEmpty
                ? 'Deepening search...'
                : 'Searching full section content...';
          });

          final enrichedSections = await _ensureSectionContentReady();
          if (!mounted || queryToken != _latestQueryToken) return;

          final enrichedRankedSections =
              enrichedSections
                  .map(
                    (entry) => _RankedSearchEntry(
                      entry: entry,
                      score: _scoreEntry(entry, tokens, phrase),
                    ),
                  )
                  .where((item) => item.score > 0)
                  .toList()
                ..sort((a, b) => b.score.compareTo(a.score));

          ranked = [...rankedPages.take(20), ...enrichedRankedSections.take(20)]
            ..sort((a, b) => b.score.compareTo(a.score));
          if (ranked.length > 20) ranked = ranked.take(20).toList();
        }
      }

      final deduped = _dedupeRankedResults(
        ranked,
        phrase,
      ).map((item) => item.entry).toList(growable: false);
      if (!mounted || queryToken != _latestQueryToken) return;

      setState(() {
        _results = deduped;
        _selectedIndex = deduped.isEmpty ? -1 : 0;
        _status = deduped.isEmpty
            ? 'No results found.'
            : '${deduped.length} result${deduped.length == 1 ? '' : 's'}';
      });

      _scrollSelectedIntoView();
    } catch (_) {
      if (!mounted || queryToken != _latestQueryToken) return;
      setState(() {
        _results = const [];
        _selectedIndex = -1;
        _status = 'Search is unavailable.';
      });
    }
  }

  void _setActiveSearchResult(int index) {
    if (_results.isEmpty) return;
    final normalized = index.clamp(0, _results.length - 1);
    setState(() {
      _selectedIndex = normalized;
    });
    Timer.run(_scrollSelectedIntoView);
  }

  void _scrollSelectedIntoView() {
    if (!kIsWeb || _selectedIndex < 0) return;
    final results = web.window.document.querySelectorAll('.docs-search-result');
    if (_selectedIndex >= results.length) return;
    final node = results.item(_selectedIndex);
    if (node is web.HTMLElement) {
      node.scrollIntoView();
    }
  }

  void _navigateTo(String url) {
    if (!kIsWeb) return;
    _closeSearch();
    web.window.location.assign(withDocsBasePath(url));
  }
}

class _DocsSearchCache {
  static Map<String, Object?>? manifest;
  static Future<Map<String, Object?>>? loadingManifest;
  static List<_SearchEntry> pages = const [];
  static Future<List<_SearchEntry>>? loadingPages;
  static List<_SearchEntry> sections = const [];
  static Future<List<_SearchEntry>>? loadingSections;
  static Future<List<_SearchEntry>>? loadingSectionContent;
  static bool sectionsContentReady = false;

  static bool get pagesReady => pages.isNotEmpty;
  static bool get sectionsReady =>
      sections.isNotEmpty ||
      loadingSections == null && manifest?['entries'] != null;
}

Future<Map<String, Object?>> _loadSearchManifest() async {
  if (_DocsSearchCache.manifest case final manifest?) return manifest;
  if (_DocsSearchCache.loadingManifest case final loading?) return loading;

  final manifestCacheKey =
      '${_DocsSearchShellState._manifestCacheKeyPrefix}${docsBasePath}';
  final cached = _readSessionJson(manifestCacheKey);
  if (cached != null) {
    _DocsSearchCache.manifest = cached;
    return cached;
  }

  final future = _getJson('/generated/search_index.json').then((payload) {
    _DocsSearchCache.manifest = payload;
    _writeSessionJson(manifestCacheKey, payload);
    return payload;
  });
  _DocsSearchCache.loadingManifest = future;
  return future;
}

Future<List<_SearchEntry>> _ensurePagesReady() async {
  if (_DocsSearchCache.pagesReady) return _DocsSearchCache.pages;
  if (_DocsSearchCache.loadingPages case final loading?) return loading;

  final future = _loadSearchManifest().then((manifest) async {
    if (manifest['entries'] case final List<dynamic> inlineEntries) {
      final payload = {'entries': inlineEntries};
      _DocsSearchCache.pages = _mapSearchEntries(payload);
      return _DocsSearchCache.pages;
    }

    final pagesPath =
        (manifest['pages'] as String?) ?? '/generated/search_pages.json';
    final cacheKey =
        '${_DocsSearchShellState._pagesCacheKeyPrefix}${docsBasePath}:$pagesPath';
    final cached = _readSessionJson(cacheKey);
    if (cached != null) {
      _DocsSearchCache.pages = _mapSearchEntries(cached);
      return _DocsSearchCache.pages;
    }

    final payload = await _getJson(pagesPath);
    _writeSessionJson(cacheKey, payload);
    _DocsSearchCache.pages = _mapSearchEntries(payload);
    return _DocsSearchCache.pages;
  });

  _DocsSearchCache.loadingPages = future;
  return future;
}

Future<List<_SearchEntry>> _ensureSectionsReady() async {
  if (_DocsSearchCache.sectionsReady) return _DocsSearchCache.sections;
  if (_DocsSearchCache.loadingSections case final loading?) return loading;

  final future = _loadSearchManifest().then((manifest) async {
    if (manifest['entries'] != null) {
      _DocsSearchCache.sections = const [];
      return _DocsSearchCache.sections;
    }

    final pages = await _ensurePagesReady();
    final sectionsPath =
        (manifest['sections'] as String?) ?? '/generated/search_sections.json';
    final cacheKey =
        '${_DocsSearchShellState._sectionsCachePrefix}${docsBasePath}:$sectionsPath';
    final cached = _readSessionJson(cacheKey);
    if (cached != null) {
      _DocsSearchCache.sections = _mapSearchEntries(
        cached,
        pages: pages,
        sectionRefs: true,
      );
      return _DocsSearchCache.sections;
    }

    final payload = await _getJson(sectionsPath);
    final entryCount = payload['entryCount'] as int? ?? 0;
    if (entryCount <= 25000) {
      _writeSessionJson(cacheKey, payload);
    }
    _DocsSearchCache.sections = _mapSearchEntries(
      payload,
      pages: pages,
      sectionRefs: true,
    );
    return _DocsSearchCache.sections;
  });

  _DocsSearchCache.loadingSections = future;
  return future;
}

Future<List<_SearchEntry>> _ensureSectionContentReady() async {
  if (_DocsSearchCache.sectionsContentReady) return _DocsSearchCache.sections;
  if (_DocsSearchCache.loadingSectionContent case final loading?)
    return loading;

  final future = _loadSearchManifest().then((manifest) async {
    final contentPath = manifest['sectionsContent'] as String?;
    if (contentPath == null || contentPath.isEmpty) {
      _DocsSearchCache.sectionsContentReady = true;
      return _DocsSearchCache.sections;
    }

    final payload = await _getJson(contentPath);
    final entries = ((payload['entries'] as List<dynamic>?) ?? const [])
        .map(_decodeSectionContentEntry)
        .whereType<_SectionContentEntry>()
        .toList(growable: false);
    if (entries.isEmpty || _DocsSearchCache.sections.isEmpty) {
      _DocsSearchCache.sectionsContentReady = true;
      return _DocsSearchCache.sections;
    }

    final contentByKey = {
      for (final entry in entries) entry.key: entry.content,
    };

    _DocsSearchCache.sections = _DocsSearchCache.sections
        .map((entry) {
          final content = contentByKey[entry.sectionKey];
          if (content == null) return entry;
          return entry.withContent(content);
        })
        .toList(growable: false);

    _DocsSearchCache.sectionsContentReady = true;
    return _DocsSearchCache.sections;
  });

  _DocsSearchCache.loadingSectionContent = future;
  return future;
}

Future<Map<String, Object?>> _getJson(String path) async {
  final response = await http.get(Uri.parse(withDocsBasePath(path)));
  if (response.statusCode != 200) {
    throw StateError('Request failed for $path: ${response.statusCode}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, Object?>) {
    throw StateError('Invalid JSON payload for $path');
  }
  return decoded;
}

Map<String, Object?>? _readSessionJson(String key) {
  if (!kIsWeb) return null;
  try {
    final raw = web.window.sessionStorage.getItem(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, Object?> ? decoded : null;
  } catch (_) {
    return null;
  }
}

void _writeSessionJson(String key, Map<String, Object?> value) {
  if (!kIsWeb) return;
  try {
    web.window.sessionStorage.setItem(key, jsonEncode(value));
  } catch (_) {}
}

List<_SearchEntry> _mapSearchEntries(
  Map<String, Object?> payload, {
  List<_SearchEntry>? pages,
  bool sectionRefs = false,
}) {
  final rawEntries = (payload['entries'] as List<dynamic>?) ?? const [];
  return rawEntries
      .map((rawEntry) {
        return sectionRefs
            ? _decodeSectionEntry(rawEntry, pages ?? const [])
            : _decodeSearchEntry(rawEntry);
      })
      .toList(growable: false);
}

_SearchEntry _decodeSearchEntry(Object? entry) {
  if (entry case final List<dynamic> values) {
    return _SearchEntry(
      kind: values.elementAtOrNull(0) as String? ?? 'page',
      title: values.elementAtOrNull(1) as String? ?? '',
      url: values.elementAtOrNull(2) as String? ?? '',
      section: values.elementAtOrNull(3) as String? ?? '',
      summary: values.elementAtOrNull(4) as String? ?? '',
      searchText: values.elementAtOrNull(5) as String? ?? '',
    );
  }

  final map = entry as Map<String, Object?>? ?? const {};
  return _SearchEntry(
    kind: map['kind'] as String? ?? 'page',
    title: map['title'] as String? ?? '',
    url: map['url'] as String? ?? '',
    section: map['section'] as String? ?? '',
    summary: map['summary'] as String? ?? '',
    searchText: map['searchText'] as String? ?? '',
  );
}

_SearchEntry _decodeSectionEntry(Object? entry, List<_SearchEntry> pages) {
  if (entry case final List<dynamic> values
      when values.isNotEmpty && values.first is int) {
    final pageIndex = values[0] as int;
    final page = pages.elementAtOrNull(pageIndex);
    final pageUrl = page?.url ?? '';
    final anchor = values.elementAtOrNull(1) as String? ?? '';
    return _SearchEntry(
      kind: page?.kind ?? 'page',
      title: page?.title ?? '',
      url: anchor.isNotEmpty ? '$pageUrl#$anchor' : pageUrl,
      section: values.elementAtOrNull(2) as String? ?? '',
      summary: '',
      searchText: '',
      sectionKey: '$pageIndex#$anchor',
    );
  }

  return _decodeSearchEntry(entry);
}

_SectionContentEntry? _decodeSectionContentEntry(Object? entry) {
  if (entry case final List<dynamic> values
      when values.length >= 3 && values.first is int) {
    final pageIndex = values[0] as int;
    final anchor = values[1] as String? ?? '';
    final content = values[2] as String? ?? '';
    return _SectionContentEntry('$pageIndex#$anchor', content);
  }
  return null;
}

List<String> _tokenize(String query) {
  return _normalizeSearchText(
    query,
  ).split(' ').where((token) => token.length > 1).toList(growable: false);
}

String _normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeTitleStem(String value) {
  return _normalizeSearchText(
    value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' '),
  );
}

double _frameworkUrlBoost(String url, {required bool shortSingle}) {
  if (RegExp(r'^/api/(widgets|material|cupertino|foundation)/').hasMatch(url)) {
    return shortSingle ? 158 : 32;
  }
  if (RegExp(
    r'^/api/(rendering|services|animation|gestures|painting|semantics)/',
  ).hasMatch(url)) {
    return shortSingle ? 108 : 22;
  }
  if (RegExp(r'^/api/dart-[^/]+/').hasMatch(url)) {
    return shortSingle ? 72 : 18;
  }
  return 0;
}

double _utilityUrlPenalty(String url, {required bool shortSingle}) {
  if (!shortSingle) return 0;
  if (url.startsWith('/api/package-test_')) return -120;
  if (url.startsWith('/api/package-matcher_')) return -110;
  if (url.startsWith('/api/package-path_')) return -100;
  if (url.startsWith('/api/vm_service/')) return -90;
  return 0;
}

int _camelWordCount(String value) {
  if (value.isEmpty) return 0;
  final matches = RegExp(r'[A-Z][a-z0-9]*').allMatches(value).length;
  return matches == 0 ? 1 : matches;
}

int _countOccurrences(String haystack, String needle) {
  if (haystack.isEmpty || needle.isEmpty) return 0;
  var count = 0;
  var offset = 0;
  while (true) {
    final index = haystack.indexOf(needle, offset);
    if (index == -1) return count;
    count += 1;
    offset = index + needle.length;
  }
}

double _scoreEntry(_SearchEntry entry, List<String> tokens, String phrase) {
  if (!tokens.every(entry.combined.contains)) return 0;

  var score = 0.0;
  final titleStartsAtBoundary = entry.normalizedTitle.startsWith('$phrase ');
  final titleStartsWithPhrase = entry.normalizedTitle.startsWith(phrase);
  final titleStemStartsAtBoundary = entry.titleStem.startsWith('$phrase ');
  final titleStemStartsWithPhrase = entry.titleStem.startsWith(phrase);
  final titleStemEndsWithPhrase =
      entry.titleStem.endsWith(phrase) && entry.titleStem != phrase;
  final shortSingleQuery = tokens.length == 1 && phrase.length <= 7;
  final compactTitle = entry.title.replaceAll(RegExp(r'<[^>]+>'), '');
  final phraseIndex = compactTitle.toLowerCase().indexOf(phrase);
  final charAfterPhrase =
      phraseIndex >= 0 && phraseIndex + phrase.length < compactTitle.length
      ? compactTitle[phraseIndex + phrase.length]
      : '';
  final hasUppercaseBoundaryAfterPhrase =
      charAfterPhrase.isNotEmpty && RegExp(r'[A-Z]').hasMatch(charAfterPhrase);
  final hasLowercaseContinuationAfterPhrase =
      charAfterPhrase.isNotEmpty && RegExp(r'[a-z]').hasMatch(charAfterPhrase);
  final titleWordCount = _camelWordCount(compactTitle);
  final extraTitleChars = (entry.titleStem.length - phrase.length).clamp(
    0,
    1000,
  );
  final looksLikeConstantTitle = RegExp(
    r'[A-Z0-9]+_[A-Z0-9_]+',
  ).hasMatch(entry.title);

  if (entry.section.isEmpty) score += 120;
  if (entry.normalizedTitle == phrase) score += 140;
  if (entry.titleStem == phrase) score += 130;
  if (titleStartsAtBoundary) {
    score += 110;
  } else if (titleStartsWithPhrase) {
    score += 55;
  } else if (entry.normalizedTitle.contains(phrase)) {
    score += 40;
  }

  if (!titleStartsAtBoundary && !titleStartsWithPhrase) {
    if (titleStemStartsAtBoundary) {
      score += 72;
    } else if (titleStemStartsWithPhrase) {
      score += 40;
    } else if (entry.titleStem.contains(phrase)) {
      score += 26;
    }
  }

  if (shortSingleQuery && titleStemEndsWithPhrase) score += 80;
  if (shortSingleQuery &&
      titleStartsWithPhrase &&
      hasUppercaseBoundaryAfterPhrase) {
    score += 42;
  }
  if (shortSingleQuery &&
      titleStartsWithPhrase &&
      hasLowercaseContinuationAfterPhrase) {
    score -= 18;
  }
  if (shortSingleQuery && titleStemEndsWithPhrase) {
    score += (44 - extraTitleChars * 2.5).clamp(0, 44);
    if (titleWordCount > 2) {
      score -= (titleWordCount - 2) * 18;
    }
  }

  if (entry.normalizedSection.contains(phrase)) score += 48;
  if (entry.normalizedSummary.contains(phrase)) score += 24;
  if (entry.normalizedText.contains(phrase)) score += 12;

  for (final token in tokens) {
    if (entry.normalizedTitle.startsWith(token)) {
      score += 32;
    } else if (entry.normalizedTitle.contains(token)) {
      score += 20;
    }

    if (entry.normalizedSection.startsWith(token)) {
      score += 24;
    } else if (entry.normalizedSection.contains(token)) {
      score += 14;
    }

    if (entry.normalizedSummary.contains(token)) score += 10;
    score += _countOccurrences(entry.normalizedText, token).clamp(0, 5) * 3;
  }

  if (entry.kind == 'api') score += 2;
  score += _frameworkUrlBoost(entry.url, shortSingle: shortSingleQuery);
  score += _utilityUrlPenalty(entry.url, shortSingle: shortSingleQuery);
  if (looksLikeConstantTitle) score -= 84;
  return score;
}

String _baseUrlForEntry(_SearchEntry entry) {
  final hashIndex = entry.url.indexOf('#');
  return hashIndex == -1 ? entry.url : entry.url.substring(0, hashIndex);
}

List<_RankedSearchEntry> _dedupeRankedResults(
  List<_RankedSearchEntry> ranked,
  String phrase,
) {
  final exactPageBases = ranked
      .where((item) => item.entry.section.isEmpty)
      .where(
        (item) =>
            item.entry.normalizedTitle == phrase ||
            item.entry.titleStem == phrase,
      )
      .map((item) => _baseUrlForEntry(item.entry))
      .toSet();

  final perBaseCount = <String, int>{};
  final deduped = <_RankedSearchEntry>[];
  for (final item in ranked) {
    final baseUrl = _baseUrlForEntry(item.entry);
    final currentCount = perBaseCount[baseUrl] ?? 0;
    if (item.entry.section.isNotEmpty && exactPageBases.contains(baseUrl)) {
      if (currentCount >= 1) continue;
    } else if (item.entry.section.isNotEmpty && currentCount >= 2) {
      continue;
    } else if (item.entry.section.isEmpty && currentCount >= 1) {
      continue;
    }

    perBaseCount[baseUrl] = currentCount + 1;
    deduped.add(item);
    if (deduped.length >= 20) break;
  }
  return deduped;
}

String _buildExcerpt(_SearchEntry entry, List<String> tokens) {
  final source = entry.summary.isNotEmpty ? entry.summary : entry.searchText;
  if (source.isEmpty) return '';
  if (tokens.isEmpty) return _trimExcerpt(source);

  final normalizedSource = _normalizeSearchText(source);
  final hit = tokens.firstWhere(normalizedSource.contains, orElse: () => '');
  if (hit.isEmpty) return _trimExcerpt(source);

  final exact = source.toLowerCase().indexOf(hit.toLowerCase());
  if (exact == -1) return _trimExcerpt(source);

  final start = (exact - 70).clamp(0, source.length);
  final end = (exact + 150).clamp(0, source.length);
  final prefix = start > 0 ? '...' : '';
  final suffix = end < source.length ? '...' : '';
  return '$prefix${source.substring(start, end).trim()}$suffix';
}

String _trimExcerpt(String source) {
  final excerpt = source.length <= 220
      ? source
      : '${source.substring(0, 220)}...';
  return excerpt;
}

List<Component> _buildHighlightedText(String value, List<String> tokens) {
  if (value.isEmpty) return const [];
  final ranges = _findHighlightRanges(value, tokens);
  if (ranges.isEmpty) return [Component.text(value)];

  final children = <Component>[];
  var offset = 0;
  for (final range in ranges) {
    if (offset < range.start) {
      children.add(Component.text(value.substring(offset, range.start)));
    }
    children.add(
      Component.element(
        tag: 'mark',
        children: [Component.text(value.substring(range.start, range.end))],
      ),
    );
    offset = range.end;
  }
  if (offset < value.length) {
    children.add(Component.text(value.substring(offset)));
  }
  return children;
}

List<_TextRange> _findHighlightRanges(String value, List<String> tokens) {
  if (tokens.isEmpty) return const [];
  final escapedTokens =
      tokens.where((token) => token.length > 1).toSet().toList(growable: false)
        ..sort((a, b) => b.length.compareTo(a.length));
  if (escapedTokens.isEmpty) return const [];

  final pattern = escapedTokens.map(RegExp.escape).join('|');
  final matches = RegExp(pattern, caseSensitive: false, unicode: true)
      .allMatches(value)
      .map((match) => _TextRange(match.start, match.end))
      .toList(growable: false);
  if (matches.isEmpty) return const [];

  final merged = <_TextRange>[];
  for (final match in matches) {
    if (merged.isEmpty || match.start > merged.last.end) {
      merged.add(match);
      continue;
    }
    merged[merged.length - 1] = _TextRange(
      merged.last.start,
      merged.last.end > match.end ? merged.last.end : match.end,
    );
  }
  return merged;
}

final class _SearchEntry {
  _SearchEntry({
    required this.kind,
    required this.title,
    required this.url,
    required this.section,
    required this.summary,
    required this.searchText,
    this.sectionKey = '',
  }) : normalizedTitle = _normalizeSearchText(title),
       titleStem = _normalizeTitleStem(title),
       normalizedSection = _normalizeSearchText(section),
       normalizedSummary = _normalizeSearchText(summary),
       normalizedText = _normalizeSearchText(searchText),
       combined = _normalizeSearchText(
         [
           title,
           section,
           summary,
           searchText,
         ].where((value) => value.isNotEmpty).join(' '),
       );

  final String kind;
  final String title;
  final String url;
  final String section;
  final String summary;
  final String searchText;
  final String sectionKey;

  final String normalizedTitle;
  final String titleStem;
  final String normalizedSection;
  final String normalizedSummary;
  final String normalizedText;
  final String combined;

  _SearchEntry withContent(String content) {
    return _SearchEntry(
      kind: kind,
      title: title,
      url: url,
      section: section,
      summary: content,
      searchText: content,
      sectionKey: sectionKey,
    );
  }
}

final class _RankedSearchEntry {
  const _RankedSearchEntry({required this.entry, required this.score});

  final _SearchEntry entry;
  final double score;
}

final class _SectionContentEntry {
  const _SectionContentEntry(this.key, this.content);

  final String key;
  final String content;
}

final class _TextRange {
  const _TextRange(this.start, this.end);

  final int start;
  final int end;
}
