import 'package:jaspr_content/src/page.dart';
import 'package:jaspr_content/src/template_engine/template_engine.dart';

class DocsTemplateEngine extends TemplateEngine {
  static final _codeFenceLine = RegExp(r'^\s*(```|~~~)');
  static final _containerStart = RegExp(
    r'^:::(info|note|important|warning|caution|tip|danger|details)\s*(.*)$',
  );

  @override
  Future<void> render(Page page, List<Page> pages) async {
    final normalized = _rewriteContainers(page.content);
    if (normalized != page.content) {
      page.apply(content: normalized);
    }
  }

  String _rewriteContainers(String content) {
    final lines = content.split('\n');
    final output = <String>[];
    var inCodeFence = false;
    var index = 0;

    while (index < lines.length) {
      final line = lines[index];

      if (_codeFenceLine.hasMatch(line)) {
        inCodeFence = !inCodeFence;
        output.add(line);
        index++;
        continue;
      }

      if (!inCodeFence) {
        final start = _containerStart.firstMatch(line.trim());
        if (start != null) {
          final kind = start.group(1)!;
          final title = start.group(2)!.trim();
          final bodyLines = <String>[];
          var nestedFence = false;
          var closed = false;
          var cursor = index + 1;

          for (; cursor < lines.length; cursor++) {
            final current = lines[cursor];

            if (_codeFenceLine.hasMatch(current)) {
              nestedFence = !nestedFence;
              bodyLines.add(current);
              continue;
            }

            if (!nestedFence && current.trim() == ':::') {
              closed = true;
              break;
            }

            bodyLines.add(current);
          }

          if (closed) {
            output.add(_renderContainer(kind, title, bodyLines.join('\n')));
            output.add('');
            index = cursor + 1;
            continue;
          }
        }
      }

      output.add(line);
      index++;
    }

    return output.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  String _renderContainer(String kind, String title, String body) {
    final trimmedBody = body.trimRight();

    switch (kind) {
      case 'info':
      case 'note':
      case 'important':
        return _renderCallout('Info', title, trimmedBody);
      case 'warning':
      case 'caution':
        return _renderCallout('Warning', title, trimmedBody);
      case 'tip':
        return _renderCallout('Success', title, trimmedBody);
      case 'danger':
        return _renderCallout('Error', title, trimmedBody);
      case 'details':
        final summaryText = title.isEmpty ? 'Details' : _escapeHtml(title);
        final parts = <String>['<details>', '<summary>$summaryText</summary>'];
        if (trimmedBody.isNotEmpty) {
          parts
            ..add('')
            ..add(trimmedBody)
            ..add('');
        }
        parts.add('</details>');
        return parts.join('\n');
      default:
        return body;
    }
  }

  String _renderCallout(String tag, String title, String body) {
    final parts = <String>['<$tag>'];
    final trimmedTitle = title.trim();

    if (trimmedTitle.isNotEmpty) {
      parts
        ..add('')
        ..add('**${_escapeMarkdownInline(trimmedTitle)}**');
    }

    if (body.isNotEmpty) {
      parts
        ..add('')
        ..add(body);
    }

    if (parts.length == 1) {
      parts.add('');
    }

    parts
      ..add('')
      ..add('</$tag>');
    return parts.join('\n');
  }

  String _escapeMarkdownInline(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('*', r'\*')
      .replaceAll('_', r'\_')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]')
      .replaceAll('`', r'\`');

  String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
