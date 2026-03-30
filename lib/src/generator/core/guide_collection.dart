// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Format-agnostic guide file collection and parsing.
///
/// Collects markdown files from package `doc/`/`docs/` directories,
/// extracts titles and frontmatter, and returns structured [GuideEntry]
/// objects. Sidebar output formatting is format-specific and NOT included here.
library;

import 'package:path/path.dart' as p;

/// Matches a markdown level-1 heading (e.g. `# My Title`).
final _headingPattern = RegExp(r'^#\s+(.+)$');

/// Matches inline markdown formatting (`**bold**`, `*italic*`, `` `code` ``).
final _inlineMarkdown = RegExp(r'\*{1,2}|`');

/// Matches hyphens or underscores for kebab/snake-case splitting.
final _kebabSnakeDelimiter = RegExp(r'[-_]');

/// Matches YAML frontmatter block delimited by `---`.
final frontmatterPattern = RegExp(r'^---\n([\s\S]*?)\n---', multiLine: true);

/// Matches `sidebar_position: <number>` in frontmatter.
final _sidebarPositionPattern =
    RegExp(r'^sidebar_position:\s*(\d+)\s*$', multiLine: true);

/// An entry representing a single guide markdown file.
class GuideEntry {
  final String packageName;

  /// Output path relative to the output root (e.g. `guide/pkg/intro.md`).
  final String relativePath;

  final String title;

  /// The raw markdown content read from the source file.
  final String content;

  /// Optional sidebar position from frontmatter `sidebar_position`.
  /// Lower values appear first. `null` means no explicit order (sorted last).
  final int? sidebarPosition;

  GuideEntry({
    required this.packageName,
    required this.relativePath,
    required this.title,
    required this.content,
    this.sidebarPosition,
  });
}

/// Extracts a title from the markdown content.
///
/// Looks for the first `# heading` line. Falls back to the file name
/// (without extension) converted from kebab/snake case to title case.
String extractTitle(String content, String relativePath) {
  final lines = content.split('\n');
  for (final line in lines) {
    final match = _headingPattern.firstMatch(line.trim());
    if (match != null) {
      return _stripInlineMarkdown(match.group(1)!.trim());
    }
  }

  // Fallback: use the file name.
  var name = p.basenameWithoutExtension(relativePath);
  // Convert kebab-case or snake_case to Title Case.
  name = name
      .replaceAll(_kebabSnakeDelimiter, ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  return name;
}

/// Strips inline markdown formatting from a heading title.
String _stripInlineMarkdown(String title) =>
    title.replaceAll(_inlineMarkdown, '').trim();

/// Extracts `sidebar_position` from YAML frontmatter if present.
int? extractSidebarPosition(String content) {
  final fmMatch = frontmatterPattern.firstMatch(content);
  if (fmMatch == null) return null;
  final posMatch = _sidebarPositionPattern.firstMatch(fmMatch.group(1)!);
  if (posMatch == null) return null;
  return int.tryParse(posMatch.group(1)!);
}

/// Sorts guide entries: by `sidebarPosition` first (ascending),
/// entries without position go last, sorted by title alphabetically.
List<GuideEntry> sortGuideEntries(List<GuideEntry> entries) {
  entries.sort((a, b) {
    if (a.sidebarPosition != null && b.sidebarPosition != null) {
      return a.sidebarPosition!.compareTo(b.sidebarPosition!);
    }
    if (a.sidebarPosition != null) return -1;
    if (b.sidebarPosition != null) return 1;
    return a.title.compareTo(b.title);
  });
  return entries;
}
