import 'dart:convert';
import 'dart:io';

final _nonLetterOrDigit = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final _whitespace = RegExp(r'\s+');

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/jaspr_search_benchmark.dart <search_index.json> [query ...]',
    );
    exitCode = 64;
    return;
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('Search index not found: ${file.path}');
    exitCode = 66;
    return;
  }

  final readWatch = Stopwatch()..start();
  final raw = file.readAsStringSync();
  readWatch.stop();

  final parseWatch = Stopwatch()..start();
  final payload = jsonDecode(raw) as Map<String, Object?>;
  final entries = _loadEntries(file, payload);
  parseWatch.stop();

  final queries = args.length > 1
      ? args.skip(1).toList()
      : _defaultQueries(entries);

  stdout.writeln('entries: ${entries.length}');
  stdout.writeln('size_bytes: ${file.lengthSync()}');
  stdout.writeln('read_ms: ${readWatch.elapsedMilliseconds}');
  stdout.writeln('parse_ms: ${parseWatch.elapsedMilliseconds}');
  stdout.writeln(
    'avg_search_text_chars: ${entries.isEmpty ? 0 : (entries.map((e) => e.searchText.length).reduce((a, b) => a + b) / entries.length).toStringAsFixed(1)}',
  );
  stdout.writeln();

  for (final query in queries) {
    final searchWatch = Stopwatch()..start();
    final results = _search(entries, query);
    searchWatch.stop();

    stdout.writeln('query: $query');
    stdout.writeln('search_ms: ${searchWatch.elapsedMicroseconds / 1000}');
    if (results.isEmpty) {
      stdout.writeln('  no_results');
      stdout.writeln();
      continue;
    }

    for (final result in results.take(5)) {
      stdout.writeln(
        '  - [${result.kind}] ${result.title}'
        '${result.section == null ? '' : ' > ${result.section}'}'
        ' -> ${result.url}',
      );
    }
    stdout.writeln();
  }
}

List<_SearchEntry> _loadEntries(File file, Map<String, Object?> payload) {
  final directEntries = payload['entries'] as List<Object?>?;
  if (directEntries != null) {
    final version = payload['version'];
    final pages = version == 3 || version == 4
        ? _loadSiblingPageEntries(file)
        : null;
    return directEntries
        .map((entry) => _SearchEntry.fromJson(entry, pages: pages))
        .toList(growable: false);
  }

  final allEntries = <_SearchEntry>[];
  List<_SearchEntry>? pages;
  List<_SearchEntry>? sections;
  final parent = file.parent;
  for (final key in ['pages', 'sections', 'sectionsContent']) {
    final relativePath = payload[key] as String?;
    if (relativePath == null || relativePath.isEmpty) continue;
    final normalizedPath = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    final chunkFile = File('${parent.parent.path}/$normalizedPath');
    if (!chunkFile.existsSync()) continue;
    final chunkPayload =
        jsonDecode(chunkFile.readAsStringSync()) as Map<String, Object?>;
    final chunkVersion = chunkPayload['version'];
    final chunkEntries = (chunkPayload['entries'] as List<Object?>? ?? const [])
        .map(
          (entry) => _SearchEntry.fromJson(
            entry,
            pages: chunkVersion == 3 || chunkVersion == 4 ? pages : null,
          ),
        )
        .toList(growable: false);
    if (key == 'sectionsContent' && sections != null) {
      _mergeSectionContent(sections, chunkEntries);
      continue;
    }
    allEntries.addAll(chunkEntries);
    if (key == 'pages') {
      pages = allEntries.toList(growable: false);
    } else if (key == 'sections') {
      sections = chunkEntries;
    }
  }
  return allEntries;
}

List<_SearchEntry> _loadSiblingPageEntries(File file) {
  final sibling = File('${file.parent.path}/search_pages.json');
  if (!sibling.existsSync()) return const [];
  final payload =
      jsonDecode(sibling.readAsStringSync()) as Map<String, Object?>;
  final entries = payload['entries'] as List<Object?>? ?? const [];
  return entries.map(_SearchEntry.fromJson).toList(growable: false);
}

void _mergeSectionContent(
  List<_SearchEntry> sections,
  List<_SearchEntry> contentEntries,
) {
  final byUrl = {for (final entry in contentEntries) entry.url: entry};
  for (final section in sections) {
    final contentEntry = byUrl[section.url];
    if (contentEntry == null || contentEntry.searchText.isEmpty) continue;
    section
      ..summary = contentEntry.searchText
      ..searchText = contentEntry.searchText
      ..refreshDerivedFields();
  }
}

List<String> _defaultQueries(List<_SearchEntry> entries) {
  final corpus = entries.map((entry) => entry.title).join(' ');
  final candidates = <String>[
    'Future',
    'Stream',
    'Uri',
    'File',
    'HttpClient',
    'Utf8Decoder',
  ];
  return [
    for (final query in candidates)
      if (corpus.contains(query)) query,
  ].take(4).toList();
}

List<_SearchEntry> _search(List<_SearchEntry> entries, String query) {
  final phrase = _normalize(query);
  final tokens = phrase.split(' ').where((token) => token.length > 1).toList();
  if (tokens.isEmpty) return const [];

  final ranked = <({double score, _SearchEntry entry})>[];
  for (final entry in entries) {
    if (!tokens.every(entry.combined.contains)) {
      continue;
    }

    var score = 0.0;
    final titleStartsAtBoundary = entry.titleText.startsWith('$phrase ');
    final titleStartsWithPhrase = entry.titleText.startsWith(phrase);
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
        charAfterPhrase.isNotEmpty &&
        RegExp(r'[A-Z]').hasMatch(charAfterPhrase);
    final hasLowercaseContinuationAfterPhrase =
        charAfterPhrase.isNotEmpty &&
        RegExp(r'[a-z]').hasMatch(charAfterPhrase);
    final titleWordCount = _camelWordCount(compactTitle);
    final extraTitleChars = (entry.titleStem.length - phrase.length).clamp(
      0,
      999,
    );
    final looksLikeConstantTitle = RegExp(
      r'[A-Z0-9]+_[A-Z0-9_]+',
    ).hasMatch(entry.title);
    if (entry.section == null) score += 120;
    if (entry.titleText == phrase) score += 140;
    if (entry.titleStem == phrase) score += 130;
    if (titleStartsAtBoundary) {
      score += 110;
    } else if (titleStartsWithPhrase) {
      score += 55;
    } else if (entry.titleText.contains(phrase)) {
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
    if (entry.sectionText.contains(phrase)) score += 48;
    if (entry.summaryText.contains(phrase)) score += 24;
    if (entry.searchTextText.contains(phrase)) score += 12;

    for (final token in tokens) {
      if (entry.titleText.startsWith(token)) {
        score += 32;
      } else if (entry.titleText.contains(token)) {
        score += 20;
      }

      if (entry.sectionText.startsWith(token)) {
        score += 24;
      } else if (entry.sectionText.contains(token)) {
        score += 14;
      }

      if (entry.summaryText.contains(token)) {
        score += 10;
      }
      score += _countOccurrences(entry.searchTextText, token).clamp(0, 5) * 3;
    }

    if (entry.kind == 'api') score += 2;
    score += _frameworkUrlBoost(entry.url, shortSingle: shortSingleQuery);
    score += _utilityUrlPenalty(entry.url, shortSingle: shortSingleQuery);
    if (looksLikeConstantTitle) score -= 84;
    if (score > 0) ranked.add((score: score, entry: entry));
  }

  ranked.sort((a, b) => b.score.compareTo(a.score));
  return _dedupeRankedResults(
    ranked,
    phrase,
  ).take(20).map(_entryOf).toList(growable: false);
}

_SearchEntry _entryOf(({double score, _SearchEntry entry}) item) => item.entry;

String _baseUrlForEntry(_SearchEntry entry) {
  final hashIndex = entry.url.indexOf('#');
  return hashIndex == -1 ? entry.url : entry.url.substring(0, hashIndex);
}

List<({double score, _SearchEntry entry})> _dedupeRankedResults(
  List<({double score, _SearchEntry entry})> ranked,
  String phrase,
) {
  final exactPageBases = ranked
      .where((item) => item.entry.section == null)
      .where(
        (item) =>
            item.entry.titleText == phrase || item.entry.titleStem == phrase,
      )
      .map((item) => _baseUrlForEntry(item.entry))
      .toSet();
  final perBaseCount = <String, int>{};
  final deduped = <({double score, _SearchEntry entry})>[];
  for (final item in ranked) {
    final baseUrl = _baseUrlForEntry(item.entry);
    final currentCount = perBaseCount[baseUrl] ?? 0;
    if (item.entry.section != null && exactPageBases.contains(baseUrl)) {
      if (currentCount >= 1) continue;
    } else if (item.entry.section != null && currentCount >= 2) {
      continue;
    } else if (item.entry.section == null && currentCount >= 1) {
      continue;
    }
    perBaseCount[baseUrl] = currentCount + 1;
    deduped.add(item);
    if (deduped.length >= 20) break;
  }
  return deduped;
}

int _countOccurrences(String haystack, String needle) {
  var count = 0;
  var offset = 0;
  while (true) {
    final index = haystack.indexOf(needle, offset);
    if (index == -1) return count;
    count++;
    offset = index + needle.length;
  }
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(_nonLetterOrDigit, ' ')
      .replaceAll(_whitespace, ' ')
      .trim();
}

String _normalizeTitleStem(String value) {
  return _normalize(
    value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' '),
  );
}

double _frameworkUrlBoost(String url, {bool shortSingle = false}) {
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

double _utilityUrlPenalty(String url, {bool shortSingle = false}) {
  if (!shortSingle) return 0;
  if (RegExp(r'^/api/package-test_').hasMatch(url)) return -120;
  if (RegExp(r'^/api/package-matcher_').hasMatch(url)) return -110;
  if (RegExp(r'^/api/package-path_').hasMatch(url)) return -100;
  if (RegExp(r'^/api/vm_service/').hasMatch(url)) return -90;
  return 0;
}

int _camelWordCount(String value) {
  final matches = RegExp(r'[A-Z][a-z0-9]*').allMatches(value).length;
  if (matches > 0) return matches;
  return value.trim().isEmpty ? 0 : 1;
}

class _SearchEntry {
  _SearchEntry({
    required this.kind,
    required this.title,
    required this.section,
    required this.url,
    required this.summary,
    required this.searchText,
  }) {
    refreshDerivedFields();
  }

  factory _SearchEntry.fromJson(Object? json, {List<_SearchEntry>? pages}) {
    if (json is List<Object?>) {
      if (json.isNotEmpty && json.first is int) {
        final page = pages != null && (json.first as int) < pages.length
            ? pages[json.first as int]
            : null;
        final pageUrl = page?.url ?? '';
        final anchor = json.length > 1 ? json[1] as String? ?? '' : '';
        final content = json.length > 3 ? json[3] as String? ?? '' : '';
        return _SearchEntry(
          kind: page?.kind ?? 'page',
          title: page?.title ?? '',
          url: anchor.isEmpty ? pageUrl : '$pageUrl#$anchor',
          section: json.length > 2 ? json[2] as String? : null,
          summary: '',
          searchText: content,
        );
      }
      return _SearchEntry(
        kind: json.isNotEmpty ? json[0] as String? ?? 'page' : 'page',
        title: json.length > 1 ? json[1] as String? ?? '' : '',
        url: json.length > 2 ? json[2] as String? ?? '' : '',
        section: json.length > 3 ? json[3] as String? : null,
        summary: json.length > 4 ? json[4] as String? ?? '' : '',
        searchText: json.length > 5 ? json[5] as String? ?? '' : '',
      );
    }

    final map = (json as Map<String, Object?>).cast<String, Object?>();
    return _SearchEntry(
      kind: map['kind'] as String? ?? 'page',
      title: map['title'] as String? ?? '',
      section: map['section'] as String?,
      url: map['url'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      searchText: map['searchText'] as String? ?? '',
    );
  }

  final String kind;
  final String title;
  final String? section;
  final String url;
  String summary;
  String searchText;

  late String titleText;
  late String titleStem;
  late String sectionText;
  late String summaryText;
  late String searchTextText;
  late String combined;

  void refreshDerivedFields() {
    titleText = _normalize(title);
    titleStem = _normalizeTitleStem(title);
    sectionText = _normalize(section ?? '');
    summaryText = _normalize(summary);
    searchTextText = _normalize(searchText);
    combined = _normalize(
      [title, if (section != null) section, summary, searchText].join(' '),
    );
  }
}
