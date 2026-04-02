import 'package:jaspr_content/src/page.dart';
import 'package:jaspr_content/src/page_extension/page_extension.dart';
import 'package:jaspr_content/src/page_parser/page_parser.dart';

import '../docs_base.dart';
import '../generated/api_symbols.dart' as generated;

class ApiLinkerExtension implements PageExtension {
  const ApiLinkerExtension();

  static const _ignore = {
    'String',
    'int',
    'double',
    'bool',
    'num',
    'dynamic',
    'void',
    'Object',
    'List',
    'Map',
    'Set',
    'Future',
    'Stream',
    'Iterable',
    'Type',
    'Function',
    'Null',
    'Never',
    'Record',
    'Duration',
    'DateTime',
    'Uri',
    'RegExp',
    'Error',
    'Exception',
    'Completer',
    'Timer',
    'StreamController',
    'Stopwatch',
    'T',
    'E',
    'K',
    'V',
    'R',
    'S',
    'Widget',
    'BuildContext',
    'State',
    'StatelessWidget',
    'StatefulWidget',
    'Key',
    'GlobalKey',
    'InheritedWidget',
    'InheritedNotifier',
    'Navigator',
    'Route',
    'ModalRoute',
    'RouteObserver',
    'PageRoute',
    'MaterialApp',
    'Scaffold',
    'Text',
    'Center',
    'Column',
    'Row',
    'Container',
    'SizedBox',
    'Padding',
    'ElevatedButton',
    'TextButton',
    'CircularProgressIndicator',
    'MaterialPageRoute',
  };

  static final _identifierPattern = RegExp(r'^([A-Z][A-Za-z0-9]*)(?:\.(.+))?$');

  @override
  Future<List<Node>> apply(Page page, List<Node> nodes) async {
    return _rewriteNodes(
      nodes,
      symbolMap: generated.apiSymbolMap,
      pagePath: page.path,
      currentApiDir: _currentApiDir(page.path),
    );
  }

  List<Node> _rewriteNodes(
    List<Node> nodes, {
    required Map<String, List<generated.ApiSymbolEntry>> symbolMap,
    required String pagePath,
    required String? currentApiDir,
    bool insideLink = false,
    bool insideCodeBlock = false,
  }) {
    return [
      for (final node in nodes)
        _rewriteNode(
          node,
          symbolMap: symbolMap,
          pagePath: pagePath,
          currentApiDir: currentApiDir,
          insideLink: insideLink,
          insideCodeBlock: insideCodeBlock,
        ),
    ];
  }

  Node _rewriteNode(
    Node node, {
    required Map<String, List<generated.ApiSymbolEntry>> symbolMap,
    required String pagePath,
    required String? currentApiDir,
    required bool insideLink,
    required bool insideCodeBlock,
  }) {
    if (node is! ElementNode) return node;

    final isLink = insideLink || node.tag == 'a';
    final isCodeBlock = insideCodeBlock || node.tag == 'pre';

    if (!isLink &&
        !isCodeBlock &&
        node.tag == 'code' &&
        node.children != null &&
        node.children!.isNotEmpty) {
      final linked = _linkInlineCode(
        node,
        symbolMap: symbolMap,
        pagePath: pagePath,
        currentApiDir: currentApiDir,
      );
      if (linked != null) return linked;
    }

    return ElementNode(
      node.tag,
      node.attributes,
      _rewriteNodes(
        node.children ?? const [],
        symbolMap: symbolMap,
        pagePath: pagePath,
        currentApiDir: currentApiDir,
        insideLink: isLink,
        insideCodeBlock: isCodeBlock,
      ),
    );
  }

  Node? _linkInlineCode(
    ElementNode codeNode, {
    required Map<String, List<generated.ApiSymbolEntry>> symbolMap,
    required String pagePath,
    required String? currentApiDir,
  }) {
    final content = codeNode.innerText.trim();
    final match = _identifierPattern.firstMatch(content);
    if (match == null) return null;

    final symbol = match.group(1)!;
    if (_ignore.contains(symbol)) return null;

    final entries = _resolveEntries(symbolMap, symbol, match.group(2));
    if (entries == null || entries.isEmpty) return null;

    final entry = _pickEntry(entries, currentApiDir);
    if (entry.relativePath == pagePath.replaceAll('\\', '/')) {
      return null;
    }

    return ElementNode(
      'a',
      {'href': withDocsBasePath(entry.href), 'class': 'api-link'},
      [codeNode],
    );
  }

  List<generated.ApiSymbolEntry>? _resolveEntries(
    Map<String, List<generated.ApiSymbolEntry>> symbolMap,
    String symbol,
    String? memberPath,
  ) {
    final normalizedMember = _normalizeMemberPath(memberPath);
    if (normalizedMember != null) {
      final qualifiedKey = '$symbol.$normalizedMember';
      final qualifiedEntries = symbolMap[qualifiedKey];
      if (qualifiedEntries != null && qualifiedEntries.isNotEmpty) {
        return qualifiedEntries;
      }
    }
    return symbolMap[symbol];
  }

  String? _normalizeMemberPath(String? memberPath) {
    if (memberPath == null) return null;
    var normalized = memberPath.trim();
    if (normalized.isEmpty) return null;
    normalized = normalized.replaceFirst(RegExp(r'\(\)$'), '').trim();
    normalized = normalized.replaceFirst(RegExp(r'<[^>]+>$'), '').trim();
    if (normalized.startsWith('operator ')) {
      final operatorName = normalized.substring('operator '.length).trim();
      if (operatorName.isEmpty) return null;
      return 'operator $operatorName';
    }
    if (normalized.endsWith('=')) {
      normalized = normalized.substring(0, normalized.length - 1).trim();
    }
    return normalized.isEmpty ? null : normalized;
  }

  generated.ApiSymbolEntry _pickEntry(
    List<generated.ApiSymbolEntry> entries,
    String? currentApiDir,
  ) {
    if (entries.length == 1 || currentApiDir == null) {
      return entries.first;
    }

    for (final entry in entries) {
      if (entry.apiDir == currentApiDir) return entry;
    }

    return entries.first;
  }

  static String? _currentApiDir(String pagePath) {
    final normalized = pagePath.replaceAll('\\', '/');
    if (!normalized.startsWith('api/')) return null;
    final parts = normalized.split('/');
    return parts.length >= 2 ? parts[1] : null;
  }
}
