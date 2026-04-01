// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/file_system/file_system.dart';
import 'package:dartdoc_vitepress/src/generator/core/guide_collection.dart'
    as guide_core;
import 'package:dartdoc_vitepress/src/generator/core/guide_collection.dart'
    show GuideEntry;
import 'package:dartdoc_vitepress/src/generator/vitepress_doc_processor.dart';
import 'package:dartdoc_vitepress/src/generator/vitepress_sidebar_generator.dart'
    show escapeForTs;
import 'package:dartdoc_vitepress/src/model/model.dart';
import 'package:meta/meta.dart';

// Re-export GuideEntry so existing importers don't break.
export 'package:dartdoc_vitepress/src/generator/core/guide_collection.dart'
    show GuideEntry;

/// Generates guide pages from `doc/` and `docs/` directories of packages.
///
/// Scans configured directories in each local package for `.md` files,
/// collects them as [GuideEntry] objects, and generates a VitePress
/// sidebar configuration file.
///
/// This class does NOT write files itself. Instead, it returns entries
/// with content so the caller (backend) can write them via its own
/// `_writeMarkdown()` to get incremental checks and statistics.
class VitePressGuideGenerator {
  final ResourceProvider resourceProvider;
  final List<String> scanDirs;
  final Set<String> _allowedIframeHosts;
  late final guide_core.GuideCollector _collector;

  /// Creates a guide generator with validated regex patterns.
  ///
  /// Throws [FormatException] if any [include] or [exclude] pattern
  /// is not a valid regular expression.
  VitePressGuideGenerator({
    required this.resourceProvider,
    required this.scanDirs,
    List<String> include = const [],
    List<String> exclude = const [],
    Set<String> allowedIframeHosts = const {},
  }) : _allowedIframeHosts = allowedIframeHosts {
    _collector = guide_core.GuideCollector(
      resourceProvider: resourceProvider,
      scanDirs: scanDirs,
      include: include,
      exclude: exclude,
    );
  }

  /// Scans `doc/`/`docs/` in each local package and collects `.md` files.
  ///
  /// Returns a list of [GuideEntry] containing the content and output paths.
  /// The caller is responsible for writing the files.
  List<GuideEntry> collectGuideEntries({
    required PackageGraph packageGraph,
    required bool isMultiPackage,
  }) {
    return _collector.collectGuideEntries(
      packageGraph: packageGraph,
      isMultiPackage: isMultiPackage,
      transformContent: (content, _, _) {
        final tocAdjusted = content.replaceAll(
          RegExp(r'^\[TOC\]\s*$', multiLine: true),
          '[[toc]]',
        );
        return VitePressDocProcessor.sanitizeHtml(
          tocAdjusted,
          extraAllowedHosts: _allowedIframeHosts,
        );
      },
    );
  }

  /// Generates VitePress sidebar TypeScript for guide entries.
  ///
  /// For multi-package: groups entries by package name.
  /// For single-package: flat list of items.
  ///
  /// Returns the content of `guide-sidebar.ts`.
  String generateSidebar(
    List<GuideEntry> entries, {
    required bool isMultiPackage,
  }) {
    if (entries.isEmpty) {
      return "import type { DefaultTheme } from 'vitepress'\n\n"
          'export const guideSidebar: DefaultTheme.Sidebar = {}\n';
    }

    final buffer = StringBuffer();
    buffer.writeln("import type { DefaultTheme } from 'vitepress'");
    buffer.writeln();
    buffer.writeln('export const guideSidebar: DefaultTheme.Sidebar = {');
    buffer.writeln("  '/guide/': [");

    if (isMultiPackage) {
      // Group by package.
      final byPackage = <String, List<GuideEntry>>{};
      for (final entry in entries) {
        byPackage.putIfAbsent(entry.packageName, () => []).add(entry);
      }

      for (final packageName in byPackage.keys.toList()..sort()) {
        final packageEntries =
            guide_core.sortGuideEntries(byPackage[packageName]!);
        buffer.writeln('    {');
        buffer.writeln("      text: '${escapeForTs(packageName)}',");
        buffer.writeln('      collapsed: false,');
        buffer.writeln('      items: [');
        for (final entry in packageEntries) {
          final link = '/${entry.relativePath}'.replaceAll('.md', '');
          buffer.writeln(
            "        { text: '${escapeForTs(entry.title)}', "
            "link: '${escapeForTs(link)}' },",
          );
        }
        buffer.writeln('      ],');
        buffer.writeln('    },');
      }
    } else {
      // Flat list.
      final sorted = guide_core.sortGuideEntries(entries);
      for (final entry in sorted) {
        final link = '/${entry.relativePath}'.replaceAll('.md', '');
        buffer.writeln(
          "    { text: '${escapeForTs(entry.title)}', link: '${escapeForTs(link)}' },",
        );
      }
    }

    buffer.writeln('  ],');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Checks if [relativePath] passes the include/exclude filters.
  ///
  /// Rules:
  /// - If include patterns are non-empty, the path must match at least one.
  /// - If exclude patterns are non-empty, the path must NOT match any.
  /// - If both are empty, the path passes.
  @visibleForTesting
  bool matchesFilters(String relativePath) {
    return _collector.matchesFilters(relativePath);
  }
}
