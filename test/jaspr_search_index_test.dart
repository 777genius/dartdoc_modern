import 'package:dartdoc_modern/src/generator/jaspr/search_index.dart';
import 'package:test/test.dart';

void main() {
  group('JasprSearchIndexBuilder', () {
    test('builds page and section entries with stable URLs', () {
      const markdown = '''---
title: Apple
description: Apple API reference.
---

# Apple

Top-level overview for `Apple`.

## Apple()

Creates a new Apple.

## slice()

Use [slice](/api/ex/Apple#slice) to cut the apple.
''';

      final entries = JasprSearchIndexBuilder.buildEntriesForPage(
        relativePath: 'content/api/ex/Apple.md',
        markdown: markdown,
      );

      expect(entries, hasLength(3));
      expect(entries.first.title, 'Apple');
      expect(entries.first.section, isNull);
      expect(entries.first.url, '/api/ex/Apple');
      expect(entries.first.summary, 'Apple API reference.');

      expect(entries[1].section, 'Apple()');
      expect(entries[1].url, '/api/ex/Apple#apple');
      expect(
        entries[1].summary.isNotEmpty || entries[1].searchText.isNotEmpty,
        isTrue,
      );
      expect(
        '${entries[1].summary} ${entries[1].searchText}',
        contains('Creates a new Apple.'),
      );

      expect(entries[2].section, 'slice()');
      expect(entries[2].url, '/api/ex/Apple#slice');
      expect(
        '${entries[2].summary} ${entries[2].searchText}',
        contains('slice'),
      );
    });

    test('normalizes guide content and strips raw markdown noise', () {
      const markdown = '''
# Getting Started

:::tip Useful
Read the guide carefully.
:::

<ApiBreadcrumb />

```dart
void hiddenSnippet() {}
```

## Next Steps

Continue with `Greeter`.
''';

      final entries = JasprSearchIndexBuilder.buildEntriesForPage(
        relativePath: 'content/guide/getting-started.md',
        markdown: markdown,
      );

      expect(entries.first.url, '/guide/getting-started');
      expect(
        '${entries.first.summary} ${entries.first.searchText}',
        contains('Read the guide carefully.'),
      );
      expect(
        '${entries.first.summary} ${entries.first.searchText}',
        isNot(contains('hiddenSnippet')),
      );
      expect(
        '${entries.first.summary} ${entries.first.searchText}',
        isNot(contains('<ApiBreadcrumb')),
      );
      expect(entries[1].url, '/guide/getting-started#next-steps');
      expect(
        '${entries[1].summary} ${entries[1].searchText}',
        contains('Greeter'),
      );
    });

    test('omits redundant searchText from compact page entries', () {
      const markdown = '''---
title: Overview
description: Short summary.
---

# Overview

Short summary.
''';

      final entries = JasprSearchIndexBuilder.buildEntriesForPage(
        relativePath: 'content/guide/index.md',
        markdown: markdown,
      );

      expect(entries, hasLength(1));
      expect(entries.single.summary, 'Short summary.');
      expect(entries.single.searchText, isEmpty);
      expect(entries.single.toJson(), hasLength(5));
    });
  });
}
