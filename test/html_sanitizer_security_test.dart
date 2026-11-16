// Copyright (c) 2026, the Dart project authors.
// Use of this source code is governed by a BSD-style license.

import 'package:dartdoc_modern/src/generator/core/html_sanitizer.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeHtml URL attributes', () {
    for (final unsafeUrl in <String>[
      'javascript:alert(1)',
      'JaVaScRiPt:alert(1)',
      'jav&#x61;script:alert(1)',
      'javascript&#58;alert(1)',
      'java&#10;script:alert(1)',
      'data:text/html,alert(1)',
      'vbscript:msgbox(1)',
      'file:///etc/passwd',
    ]) {
      test('removes unsafe href: $unsafeUrl', () {
        expect(
          sanitizeHtml('<a href="$unsafeUrl">open</a>'),
          '<a>open</a>',
        );
      });
    }

    test('removes unsafe src in an image', () {
      expect(
        sanitizeHtml('<img src="jav&#x61;script:alert(1)">'),
        '<img>',
      );
    });

    test('removes unsafe unquoted URL attribute', () {
      expect(
        sanitizeHtml('<a href=javascript:alert(1)>open</a>'),
        '<a>open</a>',
      );
    });

    test('preserves safe absolute and relative URLs', () {
      const safeUrls = <String>[
        'https://dart.dev/guides',
        'http://example.com',
        '/api/reference.html',
        '#class-member',
        'mailto:maintainer@example.com',
        'tel:+12345678',
      ];
      for (final url in safeUrls) {
        final markup = '<a href="$url">open</a>';
        expect(sanitizeHtml(markup), markup);
      }
    });

    test('allowed iframe cannot retain executable srcdoc HTML', () {
      const html = '<iframe src="https://www.youtube.com/embed/example" '
          'srcdoc="&lt;script&gt;alert(1)&lt;/script&gt;"></iframe>';
      expect(
        sanitizeHtml(html),
        '<iframe src="https://www.youtube.com/embed/example"></iframe>',
      );
    });

    test('iframe whitelist ignores a trusted host in data-src', () {
      expect(
        sanitizeHtml(
          '<iframe data-src="https://www.youtube.com/embed/safe" '
          'src="https://attacker.invalid/"></iframe>',
        ),
        isEmpty,
      );
    });

    test('iframe whitelist ignores a trusted host in non-src attributes', () {
      expect(
        sanitizeHtml(
          '<iframe title="https://dartpad.dev" '
          'src="https://attacker.invalid/"></iframe>',
        ),
        isEmpty,
      );
    });

    test('iframe host cannot be spoofed by a nested src in srcdoc', () {
      expect(
        sanitizeHtml(
          '<iframe srcdoc=\'src="https://www.youtube.com/embed/safe"\' '
          'src="https://attacker.invalid/"></iframe>',
        ),
        isEmpty,
      );
    });

    test('removes unquoted srcdoc from allowed iframe', () {
      const html =
          '<iframe src="https://dartpad.dev/embed" srcdoc=javascript:alert(1)></iframe>';
      expect(
        sanitizeHtml(html),
        '<iframe src="https://dartpad.dev/embed"></iframe>',
      );
    });

    test('rejects solidus-separated unsafe link', () {
      expect(
        sanitizeHtml('<a/href="javascript:alert(1)">open</a>'),
        '<a>open</a>',
      );
    });

    test('rejects adjacent unsafe URL after a quoted attribute', () {
      expect(
        sanitizeHtml('<a title="read"href="javascript:alert(1)">open</a>'),
        '<a title="read">open</a>',
      );
    });

    test('removes adjacent srcdoc on an allowed iframe', () {
      expect(
        sanitizeHtml(
          '<iframe src="https://www.youtube.com/embed/example"'
          'srcdoc="&lt;script&gt;alert(1)&lt;/script&gt;"></iframe>',
        ),
        '<iframe src="https://www.youtube.com/embed/example"></iframe>',
      );
    });

    test('removes solidus-separated srcdoc on an allowed iframe', () {
      expect(
        sanitizeHtml(
          '<iframe src="https://dartpad.dev/embed"'
          '/srcdoc="&lt;script&gt;alert(1)&lt;/script&gt;"></iframe>',
        ),
        '<iframe src="https://dartpad.dev/embed"></iframe>',
      );
    });

    test('removes adjacent event handlers after quoted attributes', () {
      expect(
        sanitizeHtml('<button type="button"onclick="alert(1)">go</button>'),
        '<button type="button">go</button>',
      );
    });

    test('removes unclosed iframe with an untrusted host', () {
      expect(sanitizeHtml('<iframe src="https://attacker.invalid/">'), isEmpty);
    });

    test('removes self-closing iframe without a matching close', () {
      expect(
        sanitizeHtml('<iframe src="https://www.youtube.com/embed/abc" />'),
        isEmpty,
      );
    });

    test('rejects iframe host when an attribute contains a quoted >', () {
      expect(
        sanitizeHtml(
          'before<iframe title="x > y" '
          'src="https://attacker.invalid/"></iframe>after',
        ),
        'beforeafter',
      );
    });

    test('preserves safe image source', () {
      const markup = '<img src="https://dart.dev/favicon.ico">';
      expect(sanitizeHtml(markup), markup);
    });
  });
}
