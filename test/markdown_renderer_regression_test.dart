import 'package:dartdoc_modern/src/generator/core/markdown_docs.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:test/test.dart';

void main() {
  test('ordered list numbering survives skipped image nodes', () {
    final nodes = md.Document().parse(
      '1. ![icon](image.png)\n2. second item',
    );
    final rendered = MarkdownRenderer().render(nodes);
    expect(rendered, contains('1. ![icon](image.png)'));
    expect(rendered, contains('2. second item'));
  });
}
