// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:io' as io;

import 'package:analyzer/file_system/file_system.dart';
import 'package:dartdoc_vitepress/src/dartdoc.dart'
    show Dartdoc, DartdocResults;
import 'package:dartdoc_vitepress/src/dartdoc_options.dart';
import 'package:dartdoc_vitepress/src/failure.dart';
import 'package:dartdoc_vitepress/src/logging.dart';
import 'package:dartdoc_vitepress/src/model/package_builder.dart';
import 'package:dartdoc_vitepress/src/package_meta.dart';
import 'package:dartdoc_vitepress/src/warnings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../src/utils.dart';

final _resourceProvider = pubPackageMetaProvider.resourceProvider;
final _pathContext = _resourceProvider.pathContext;

Folder _getFolder(String path) => _resourceProvider.getFolder(
  _pathContext.absolute(_pathContext.canonicalize(path)),
);

final _testPackageDir = _getFolder('testing/test_package');
final _testPackageWithDocsDir = _getFolder('testing/test_package_with_docs');

Dartdoc _buildJasprDartdoc(
  List<String> extraArgv,
  Folder pkgRoot,
  Folder outDir,
) {
  final context = generatorContextFromArgv([
    '--format',
    'jaspr',
    '--exclude-packages=args',
    ...extraArgv,
    '--input',
    pkgRoot.path,
    '--output',
    outDir.path,
  ], pubPackageMetaProvider);

  return Dartdoc.fromContext(
    context,
    PubPackageBuilder(
      context,
      pubPackageMetaProvider,
      skipUnreachableSdkLibraries: true,
    ),
  );
}

String _readOutput(Folder outDir, String relativePath) {
  final file = _resourceProvider.getFile(
    p.normalize(p.join(outDir.path, relativePath)),
  );
  expect(file.exists, isTrue, reason: 'Expected file to exist: $relativePath');
  return file.readAsStringSync();
}

bool _outputExists(Folder outDir, String relativePath) {
  return _resourceProvider
      .getFile(p.normalize(p.join(outDir.path, relativePath)))
      .exists;
}

bool _dirExists(Folder outDir, String relativePath) {
  return _resourceProvider
      .getFolder(p.normalize(p.join(outDir.path, relativePath)))
      .exists;
}

Folder _createSystemTemp(String prefix) => _resourceProvider.getFolder(
  Directory.systemTemp.createTempSync(prefix).path,
);

Folder _copyPackageFixture(Folder source, String prefix) {
  final destination = io.Directory.systemTemp.createTempSync(prefix);

  void copyDirectory(io.Directory from, io.Directory to) {
    for (final entity in from.listSync(recursive: false)) {
      final targetPath = p.join(to.path, p.basename(entity.path));
      if (entity is io.Directory) {
        final next = io.Directory(targetPath)..createSync();
        copyDirectory(entity, next);
      } else if (entity is io.File) {
        entity.copySync(targetPath);
      }
    }
  }

  copyDirectory(io.Directory(source.path), destination);
  return _resourceProvider.getFolder(destination.path);
}

bool _hasWarning(DartdocResults results, PackageWarning warning) {
  return results.packageGraph.packageWarningCounter.countedWarnings.values.any(
    (warningsByKind) => warningsByKind.containsKey(warning),
  );
}

void _runDartTool(List<String> args, String workingDirectory) {
  final result = Process.runSync(
    Platform.resolvedExecutable,
    args,
    workingDirectory: workingDirectory,
  );

  if (result.exitCode != 0) {
    final buf = StringBuffer()
      ..writeln('${result.stdout}')
      ..writeln('${result.stderr}');
    throw DartdocFailure(
      'dart ${args.join(' ')} failed: ${buf.toString().trim()}',
    );
  }
}

void _runPubGetForScaffold(String workingDirectory) {
  bool hasPackageConfig() {
    final packageConfig = io.File(
      p.join(workingDirectory, '.dart_tool', 'package_config.json'),
    );
    if (!packageConfig.existsSync()) return false;
    final content = packageConfig.readAsStringSync();
    return content.contains('"packages"');
  }

  final offlineResult = Process.runSync(Platform.resolvedExecutable, [
    'pub',
    'get',
    '--offline',
  ], workingDirectory: workingDirectory);
  if (offlineResult.exitCode == 0) {
    return;
  }
  if (hasPackageConfig()) {
    return;
  }

  final onlineResult = Process.runSync(Platform.resolvedExecutable, [
    'pub',
    'get',
  ], workingDirectory: workingDirectory);
  if (onlineResult.exitCode == 0) {
    return;
  }
  if (hasPackageConfig()) {
    return;
  }

  final buf = StringBuffer()
    ..writeln('offline:')
    ..writeln('${offlineResult.stdout}')
    ..writeln('${offlineResult.stderr}')
    ..writeln('online:')
    ..writeln('${onlineResult.stdout}')
    ..writeln('${onlineResult.stderr}');
  throw DartdocFailure('dart pub get failed: ${buf.toString().trim()}');
}

void main() {
  group('Jaspr generator e2e', () {
    setUpAll(() async {
      final optionSet = DartdocOptionRoot.fromOptionGenerators('dartdoc', [
        createDartdocProgramOptions,
        createLoggingOptions,
      ], pubPackageMetaProvider);
      optionSet.parseArguments([]);
      startLogging(isJson: false, isQuiet: true, showProgress: false);

      runPubGet(_testPackageWithDocsDir.path);
    });

    group('test_package output', () {
      late final Folder outDir;
      late final DartdocResults results;

      setUpAll(() async {
        outDir = _createSystemTemp('jaspr_e2e.');
        final dartdoc = _buildJasprDartdoc([], _testPackageDir, outDir);
        results = await dartdoc.generateDocs();
      });

      tearDownAll(() {
        outDir.delete();
      });

      test('writes Jaspr scaffold files', () {
        expect(_outputExists(outDir, 'pubspec.yaml'), isTrue);
        expect(_outputExists(outDir, 'lib/app.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/docs_base.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/main.server.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/main.client.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/main.server.options.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/main.client.options.dart'), isTrue);
        expect(_outputExists(outDir, 'web/index.html'), isTrue);
        expect(_outputExists(outDir, 'lib/theme/docs_theme.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/theme/docs_responsive.dart'), isTrue);
        expect(
          _outputExists(outDir, 'lib/components/docs_search.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_disclosure_runtime.dart'),
          isTrue,
        );
        expect(
          _outputExists(
            outDir,
            'lib/components/docs_disclosure_runtime_stub.dart',
          ),
          isTrue,
        );
        expect(
          _outputExists(
            outDir,
            'lib/components/docs_disclosure_runtime_web.dart',
          ),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_header.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_theme_toggle.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_nav_link.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_sidebar.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_sidebar_toggle.dart'),
          isTrue,
        );
        expect(
          _outputExists(
            outDir,
            'lib/components/docs_sidebar_toggle_shared.dart',
          ),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_sidebar_toggle_stub.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_sidebar_toggle_web.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_dartpad_runtime.dart'),
          isTrue,
        );
        expect(
          _outputExists(
            outDir,
            'lib/components/docs_dartpad_runtime_stub.dart',
          ),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_dartpad_runtime_web.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_mermaid_runtime.dart'),
          isTrue,
        );
        expect(
          _outputExists(
            outDir,
            'lib/components/docs_mermaid_runtime_stub.dart',
          ),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_mermaid_runtime_web.dart'),
          isTrue,
        );
        expect(_outputExists(outDir, 'lib/components/dart_pad.dart'), isTrue);
        expect(
          _outputExists(outDir, 'lib/components/mermaid_diagram.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/extensions/api_linker_extension.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/extensions/base_path_link_extension.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/layouts/api_docs_layout.dart'),
          isTrue,
        );
        expect(
          _outputExists(
            outDir,
            'lib/template_engine/docs_template_engine.dart',
          ),
          isTrue,
        );
        expect(_outputExists(outDir, 'content/index.md'), isTrue);
        expect(_outputExists(outDir, 'web/favicon.svg'), isTrue);
        expect(_outputExists(outDir, 'lib/generated/api_sidebar.dart'), isTrue);
        expect(
          _outputExists(outDir, 'lib/generated/guide_sidebar.dart'),
          isTrue,
        );
        expect(_outputExists(outDir, 'lib/generated/api_symbols.dart'), isTrue);
        expect(
          _outputExists(outDir, 'web/generated/search_index.json'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'web/generated/search_pages.json'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'web/generated/search_sections.json'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'web/generated/search_sections_content.json'),
          isTrue,
        );
        expect(_outputExists(outDir, 'web/generated/api_styles.css'), isTrue);
      });

      test('writes API markdown under content/api', () {
        expect(_outputExists(outDir, 'content/api/index.md'), isTrue);
        expect(_outputExists(outDir, 'content/api/ex/library.md'), isTrue);
        expect(_outputExists(outDir, 'content/api/ex/Apple.md'), isTrue);
      });

      test('main.server wires generated sidebars and stylesheet', () {
        final content = _readOutput(outDir, 'lib/main.server.dart');
        expect(content, contains("import 'package:jaspr/dom.dart';"));
        expect(content, contains("import 'app.dart';"));
        expect(content, contains("import 'docs_base.dart';"));
        expect(content, contains("import 'main.server.options.dart';"));
        expect(
          content,
          contains("import 'template_engine/docs_template_engine.dart';"),
        );
        expect(
          content,
          contains("href: withDocsBasePath('/generated/api_styles.css')"),
        );
        expect(
          content,
          contains("base: hasDocsBasePath ? '\$docsBasePath/' : '/'"),
        );
        expect(content, contains("rel: 'stylesheet'"));
        expect(content, contains("href: withDocsBasePath('/favicon.svg')"));
        expect(content, contains("'type': 'image/svg+xml'"));
        expect(
          content,
          contains('Jaspr.initializeApp(options: defaultServerOptions);'),
        );
        expect(content, contains("packageName: 'test_package'"));
        expect(content, contains('themePreset: themePreset'));
        expect(content, contains('templateEngine: DocsTemplateEngine()'));
        expect(
          content,
          contains("const themeName = String.fromEnvironment('DOCS_THEME'"),
        );
        expect(
          _readOutput(outDir, 'lib/docs_base.dart'),
          contains(
            "String.fromEnvironment('DOCS_BASE_PATH', defaultValue: '')",
          ),
        );
        expect(content, contains('DocsThemePresetX.parse(themeName)'));
      });

      test('shared app builder is reused by server and client entrypoints', () {
        final app = _readOutput(outDir, 'lib/app.dart');
        final client = _readOutput(outDir, 'lib/main.client.dart');
        final docsBase = _readOutput(outDir, 'lib/docs_base.dart');

        expect(app, contains('Component buildDocsApp({'));
        expect(app, contains('ContentApp('));
        expect(app, contains('TemplateEngine? templateEngine,'));
        expect(app, contains('templateEngine: templateEngine,'));
        expect(
          app,
          isNot(
            contains("import 'template_engine/docs_template_engine.dart';"),
          ),
        );
        expect(app, contains("import 'components/docs_header.dart';"));
        expect(app, contains("import 'components/docs_search.dart';"));
        expect(app, contains("import 'components/docs_sidebar.dart';"));
        expect(app, contains("import 'components/docs_theme_toggle.dart';"));
        expect(app, contains("import 'docs_base.dart';"));
        expect(app, contains("import 'generated/api_sidebar.dart' as api;"));
        expect(
          app,
          contains("import 'generated/guide_sidebar.dart' as guide;"),
        );
        expect(app, contains('header: DocsHeader('));
        expect(app, contains('title: packageName,'));
        expect(app, contains("logo: withDocsBasePath('/favicon.svg')"));
        expect(app, contains("homeHref: hasGuideLinks ? '/' : overviewHref,"));
        expect(app, contains("text: 'Guide',"));
        expect(app, contains("text: 'API Reference',"));
        expect(app, contains('const DocsSearchShell()'));
        expect(app, contains('const DocsThemeToggle()'));
        expect(app, contains('sidebar: DocsSidebar('));
        expect(app, contains('DocsSidebarGroup('));
        expect(app, contains('DocsSidebarItem('));
        expect(client, contains("import 'main.client.options.dart';"));
        expect(
          client,
          contains('Jaspr.initializeApp(options: defaultClientOptions);'),
        );
        expect(client, contains('runApp(const ClientApp());'));
        expect(client, isNot(contains("import 'app.dart';")));
        expect(client, isNot(contains('buildDocsApp(')));
        expect(docsBase, contains('String get docsBasePath {'));
        expect(docsBase, contains('bool get hasDocsBasePath =>'));
        expect(docsBase, contains('String withDocsBasePath(String path) {'));
        expect(docsBase, contains('String stripDocsBasePath(String path) {'));
      });

      test('custom layout wires feature runtimes', () {
        final app = _readOutput(outDir, 'lib/app.dart');
        final content = _readOutput(outDir, 'lib/layouts/api_docs_layout.dart');
        final header = _readOutput(outDir, 'lib/components/docs_header.dart');
        final search = _readOutput(outDir, 'lib/components/docs_search.dart');
        final pageActionsRuntime = _readOutput(
          outDir,
          'lib/components/docs_page_actions_runtime.dart',
        );
        final pageActionsRuntimeStub = _readOutput(
          outDir,
          'lib/components/docs_page_actions_runtime_stub.dart',
        );
        final pageActionsRuntimeWeb = _readOutput(
          outDir,
          'lib/components/docs_page_actions_runtime_web.dart',
        );
        final navigationRuntime = _readOutput(
          outDir,
          'lib/components/docs_navigation_runtime.dart',
        );
        final navigationRuntimeStub = _readOutput(
          outDir,
          'lib/components/docs_navigation_runtime_stub.dart',
        );
        final navigationRuntimeWeb = _readOutput(
          outDir,
          'lib/components/docs_navigation_runtime_web.dart',
        );
        final disclosureRuntime = _readOutput(
          outDir,
          'lib/components/docs_disclosure_runtime.dart',
        );
        final disclosureRuntimeStub = _readOutput(
          outDir,
          'lib/components/docs_disclosure_runtime_stub.dart',
        );
        final disclosureRuntimeWeb = _readOutput(
          outDir,
          'lib/components/docs_disclosure_runtime_web.dart',
        );
        final themeToggle = _readOutput(
          outDir,
          'lib/components/docs_theme_toggle.dart',
        );
        final navLink = _readOutput(
          outDir,
          'lib/components/docs_nav_link.dart',
        );
        final sidebar = _readOutput(outDir, 'lib/components/docs_sidebar.dart');
        final sidebarToggle = _readOutput(
          outDir,
          'lib/components/docs_sidebar_toggle.dart',
        );
        final sidebarToggleStub = _readOutput(
          outDir,
          'lib/components/docs_sidebar_toggle_stub.dart',
        );
        final sidebarToggleWeb = _readOutput(
          outDir,
          'lib/components/docs_sidebar_toggle_web.dart',
        );
        final dartPadRuntime = _readOutput(
          outDir,
          'lib/components/docs_dartpad_runtime.dart',
        );
        final dartPadRuntimeWeb = _readOutput(
          outDir,
          'lib/components/docs_dartpad_runtime_web.dart',
        );
        final mermaidRuntime = _readOutput(
          outDir,
          'lib/components/docs_mermaid_runtime.dart',
        );
        final mermaidRuntimeWeb = _readOutput(
          outDir,
          'lib/components/docs_mermaid_runtime_web.dart',
        );
        final mermaidRuntimeHelper = _readOutput(
          outDir,
          'web/docs_mermaid_runtime.js',
        );
        final mermaidDiagram = _readOutput(
          outDir,
          'lib/components/mermaid_diagram.dart',
        );
        final tocRuntime = _readOutput(
          outDir,
          'lib/components/docs_toc_runtime.dart',
        );
        final tocRuntimeStub = _readOutput(
          outDir,
          'lib/components/docs_toc_runtime_stub.dart',
        );
        final tocRuntimeWeb = _readOutput(
          outDir,
          'lib/components/docs_toc_runtime_web.dart',
        );
        expect(
          content,
          contains("import '../components/docs_dartpad_runtime.dart';"),
        );
        expect(
          content,
          isNot(contains("import '../components/docs_mermaid_runtime.dart';")),
        );
        expect(header, contains('class DocsHeader extends StatelessComponent'));
        expect(header, contains('const DocsSidebarToggle()'));
        expect(header, contains("classes: 'header-title'"));
        expect(header, contains('DocsNavLink('));
        expect(
          themeToggle,
          contains('class DocsThemeToggle extends StatefulComponent'),
        );
        expect(themeToggle, contains("id: 'docs-theme-script'"));
        expect(
          themeToggle,
          contains("window.localStorage.getItem('jaspr:theme')"),
        );
        expect(
          themeToggle,
          contains(
            "document.documentElement.setAttribute('data-theme', resolvedTheme)",
          ),
        );
        expect(themeToggle, contains("classes: 'theme-toggle'"));
        expect(themeToggle, contains("'data-docs-theme-toggle': ''"));
        expect(content, contains("import '../components/docs_nav_link.dart';"));
        expect(search, contains("import 'docs_navigation_runtime.dart';"));
        expect(search, contains("import 'docs_disclosure_runtime.dart';"));
        expect(
          content,
          isNot(contains("import '../components/docs_search.dart';")),
        );
        expect(content, isNot(contains('const DocsSearchShell()')));
        expect(content, contains('const DocsDartPadRuntime()'));
        expect(content, isNot(contains('const DocsMermaidRuntime()')));
        expect(content, contains('DocsNavLink('));
        expect(content, isNot(contains('case final Header header')));
        expect(content, isNot(contains('case final Sidebar sidebar')));
        expect(search, contains('@client'));
        expect(
          search,
          contains('class DocsSearchShell extends StatefulComponent'),
        );
        expect(search, contains('const DocsNavigationRuntime()'));
        expect(search, contains('const DocsDisclosureRuntime()'));
        expect(search, contains("classes: 'search-launcher'"));
        expect(search, contains("'data-docs-search-launcher': ''"));
        expect(search, contains('docs-search-overlay'));
        expect(search, contains("'data-docs-search-overlay': ''"));
        expect(search, contains('http.get(Uri.parse(withDocsBasePath(path)))'));
        expect(search, contains("import 'docs_nav_link.dart';"));
        expect(search, contains("import 'docs_mermaid_runtime.dart';"));
        expect(search, contains("import 'docs_toc_runtime.dart';"));
        expect(search, contains('_loadSearchManifest()'));
        expect(search, contains('_ensurePagesReady()'));
        expect(search, contains('_ensureSectionsReady()'));
        expect(search, contains('_ensureSectionContentReady()'));
        expect(search, contains('_scoreEntry('));
        expect(search, contains('_dedupeRankedResults('));
        expect(search, contains('_scheduleSearch('));
        expect(search, contains('_runSearch('));
        expect(search, contains('return DocsNavLink('));
        expect(search, contains('onNavigate: _closeSearch'));
        expect(search, contains('const DocsMermaidRuntime()'));
        expect(search, contains('const DocsTocRuntime()'));
        expect(search, contains('node.click();'));
        expect(search, contains('docs-search-footer'));
        expect(search, contains('_latestQueryToken'));
        expect(search, contains("classes: 'search-launcher-shortcut'"));
        expect(search, contains('_focusableNodesWithin('));
        expect(search, contains('docs.search.manifest.v5:'));
        expect(search, contains('docs.search.sections.v2:'));
        expect(search, contains('docs.search.pages.v2:'));
        expect(search, contains("'role': 'dialog'"));
        expect(search, contains("event.key == 'ArrowDown'"));
        expect(
          app,
          contains("import 'extensions/base_path_link_extension.dart';"),
        );
        expect(app, contains('const BasePathLinkExtension()'));
        expect(
          content,
          contains("import '../components/docs_page_actions_runtime.dart';"),
        );
        expect(content, contains('const DocsPageActionsRuntime()'));
        expect(content, contains("'data-docs-copy-link': 'true'"));
        expect(
          content,
          contains("classes: 'action-btn icon-action-btn action-btn-copy'"),
        );
        expect(
          content,
          contains("classes: 'action-btn icon-action-btn action-btn-source'"),
        );
        expect(
          pageActionsRuntime,
          contains("export 'docs_page_actions_runtime_stub.dart'"),
        );
        expect(
          pageActionsRuntimeStub,
          contains('class DocsPageActionsRuntime extends StatelessComponent'),
        );
        expect(
          pageActionsRuntimeStub,
          contains("'data-docs-page-actions-runtime': ''"),
        );
        expect(
          pageActionsRuntimeWeb,
          contains('class DocsPageActionsRuntime extends StatefulComponent'),
        );
        expect(pageActionsRuntimeWeb, contains('navigator.clipboard'));
        expect(
          pageActionsRuntimeWeb,
          contains("target.closest('[data-docs-copy-link]')"),
        );
        expect(
          pageActionsRuntimeWeb,
          contains("button.dataset['copyState'] = 'copied'"),
        );
        expect(
          navigationRuntime,
          contains("export 'docs_navigation_runtime_stub.dart'"),
        );
        expect(
          disclosureRuntime,
          contains("export 'docs_disclosure_runtime_stub.dart'"),
        );
        expect(
          disclosureRuntimeStub,
          contains('class DocsDisclosureRuntime extends StatelessComponent'),
        );
        expect(
          disclosureRuntimeWeb,
          contains('class DocsDisclosureRuntime extends StatefulComponent'),
        );
        expect(
          disclosureRuntimeWeb,
          contains("querySelectorAll('.content details')"),
        );
        expect(
          disclosureRuntimeWeb,
          contains("details.classList.add('docs-disclosure')"),
        );
        expect(disclosureRuntimeWeb, contains('event.preventDefault()'));
        expect(disclosureRuntimeWeb, contains("body.style.height = '0px'"));
        expect(
          disclosureRuntimeWeb,
          contains("body.style.height = '\${targetHeight}px'"),
        );
        expect(
          navigationRuntimeStub,
          contains('class DocsNavigationRuntime extends StatelessComponent'),
        );
        expect(
          navigationRuntimeWeb,
          contains('class DocsNavigationRuntime extends StatefulComponent'),
        );
        expect(navigationRuntimeWeb, contains('a[data-docs-nav-link]'));
        expect(navigationRuntimeWeb, contains('web.window.history.pushState'));
        expect(
          navigationRuntimeWeb,
          contains('web.DOMParser().parseFromString'),
        );
        expect(
          navigationRuntimeWeb,
          contains('_normalizeDocumentAnchors(root: nextMain)'),
        );
        expect(
          navigationRuntimeWeb,
          contains("node.setAttribute('href', withDocsBasePath(rawHref))"),
        );
        expect(
          navigationRuntimeWeb,
          contains("querySelector('.main-container')"),
        );
        expect(
          navigationRuntimeWeb,
          contains("web.window.addEventListener('popstate'"),
        );
        expect(
          navigationRuntimeWeb,
          contains(
            'if (!updateHistory) {\n      web.window.location.replace(targetUri.toString());',
          ),
        );
        expect(
          navigationRuntimeWeb,
          contains(
            "web.window.dispatchEvent(web.CustomEvent('docs:navigation'))",
          ),
        );
        expect(
          navigationRuntimeWeb,
          contains(
            'web.window.dispatchEvent(web.CustomEvent(_sidebarSyncEvent))',
          ),
        );
        expect(
          navLink,
          contains('class DocsNavLink extends StatelessComponent'),
        );
        expect(navLink, contains("'data-docs-nav-link': 'true'"));
        expect(navLink, contains('Router.maybeOf(context)'));
        expect(navLink, contains('router.preload(to)'));
        expect(navLink, contains('router.push(to, extra: extra)'));
        expect(navLink, contains('onNavigate?.call()'));
        expect(navLink, contains('_isModifiedClick('));
        expect(navLink, contains("value.startsWith('https://')"));
        expect(
          sidebar,
          contains('class DocsSidebar extends StatelessComponent'),
        );
        expect(
          sidebar,
          contains("import 'package:jaspr_content/jaspr_content.dart';"),
        );
        expect(sidebar, contains("'id': 'docs-sidebar'"));
        expect(sidebar, contains("classes: 'sidebar-close'"));
        expect(sidebar, contains("'data-docs-sidebar-close': 'true'"));
        expect(sidebar, contains('DocsNavLink('));
        expect(sidebar, contains("'sidebar-link active'"));
        expect(
          sidebarToggle,
          contains("export 'docs_sidebar_toggle_stub.dart'"),
        );
        expect(
          sidebarToggleStub,
          contains('class DocsSidebarToggle extends StatelessComponent'),
        );
        expect(sidebarToggleStub, contains("'data-docs-sidebar-toggle': ''"));
        expect(sidebarToggleStub, contains("aria-controls': 'docs-sidebar'"));
        expect(
          sidebarToggleWeb,
          contains('class DocsSidebarToggle extends StatefulComponent'),
        );
        expect(
          sidebarToggleWeb,
          contains('addEventListener(_sidebarSyncEvent'),
        );
        expect(sidebarToggleWeb, contains('void _syncFromDom() {'));
        expect(
          sidebarToggleWeb,
          contains(
            'web.window.dispatchEvent(web.CustomEvent(_sidebarSyncEvent))',
          ),
        );
        expect(sidebarToggleWeb, contains("sidebar.classList.add('open')"));
        expect(
          sidebarToggleWeb,
          contains("web.document.body?.style.overflow = 'hidden'"),
        );
        expect(
          dartPadRuntime,
          contains("export 'docs_dartpad_runtime_stub.dart'"),
        );
        expect(
          dartPadRuntimeWeb,
          contains('class DocsDartPadRuntime extends StatefulComponent'),
        );
        expect(dartPadRuntimeWeb, contains('candidate.contentWindow'));
        expect(dartPadRuntimeWeb, contains('navigator.clipboard'));
        expect(dartPadRuntimeWeb, contains('https://dartpad.dev'));
        expect(
          mermaidRuntime,
          contains("export 'docs_mermaid_runtime_stub.dart'"),
        );
        expect(
          mermaidRuntimeWeb,
          contains('class DocsMermaidRuntime extends StatelessComponent'),
        );
        expect(mermaidRuntimeWeb, contains("'data-docs-mermaid-runtime': ''"));
        expect(
          mermaidRuntimeHelper,
          contains(
            'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js',
          ),
        );
        expect(mermaidRuntimeHelper, contains('suppressErrorRendering: true'));
        expect(mermaidRuntimeHelper, contains('host.innerHTML = svg'));
        expect(mermaidRuntimeHelper, contains('window.docsRenderMermaid'));
        expect(
          mermaidRuntimeHelper,
          contains("querySelectorAll('.mermaid-diagram')"),
        );
        expect(
          mermaidRuntimeHelper,
          contains("addEventListener('docs:navigation'"),
        );
        expect(
          mermaidDiagram,
          contains("Component.text('Rendering Mermaid diagram')"),
        );
        expect(mermaidDiagram, contains("'data-mermaid-host': ''"));
        expect(mermaidDiagram, contains("'data-mermaid-fallback': ''"));
        expect(tocRuntime, contains("export 'docs_toc_runtime_stub.dart'"));
        expect(
          tocRuntimeStub,
          contains('class DocsTocRuntime extends StatelessComponent'),
        );
        expect(
          tocRuntimeWeb,
          contains('class DocsTocRuntime extends StatefulComponent'),
        );
        expect(tocRuntimeWeb, contains("querySelectorAll('.toc .toc-link')"));
        expect(tocRuntimeWeb, contains("target.link.classList.add('active')"));
        expect(
          tocRuntimeWeb,
          contains("target.link.classList.remove('active')"),
        );
        expect(tocRuntimeWeb, contains("window.addEventListener('scroll'"));
        expect(tocRuntimeWeb, contains('requestAnimationFrame('));
        expect(tocRuntimeWeb, contains("querySelector('.toc-indicator')"));
        expect(tocRuntimeWeb, contains('indicator.style.transform ='));
        expect(
          content,
          contains(
            "if (page.data['toc'] case final TableOfContents toc\n                when _hasVisibleTocEntries(toc.entries))",
          ),
        );
        expect(
          content,
          contains("final isApiPage = pagePath.startsWith('api/');"),
        );
        expect(content, contains('final hasContentHeader ='));
        expect(content, contains('!isApiPage &&'));
        expect(
          content,
          contains('bool _hasVisibleTocEntries(Iterable<TocEntry> entries)'),
        );
        expect(content, contains("'data-toc-link': entry.id"));
        expect(content, contains("classes: 'toc-indicator'"));
        expect(content, contains("classes: 'toc-link'"));
        expect(content, isNot(contains("'table-layout': 'fixed'")));
        expect(
          content,
          contains("'thead th:first-child, tbody td:first-child'"),
        );
        expect(content, contains("'min-width': '34rem'"));
        expect(content, isNot(contains('route-progress')));
        expect(content, isNot(contains('window.history.pushState(')));
        expect(content, isNot(contains('const _runtimeScript')));
      });

      test('api styles use Jaspr content tokens', () {
        final content = _readOutput(outDir, 'web/generated/api_styles.css');
        expect(content, contains('var(--content-pre-bg)'));
        expect(content, contains('var(--content-code-font)'));
        expect(content, contains('var(--content-links)'));
      });

      test('theme module exposes presets and custom docs tokens', () {
        final content = _readOutput(outDir, 'lib/theme/docs_theme.dart');
        expect(content, contains('enum DocsThemePreset'));
        expect(content, contains('DocsThemePreset.ocean'));
        expect(content, contains('DocsThemePreset.graphite'));
        expect(content, contains('DocsThemePreset.forest'));
        expect(
          content,
          contains('extension DocsThemePresetX on DocsThemePreset'),
        );
        expect(content, contains('static DocsThemePreset parse(String value)'));
        expect(content, contains('class DocsThemeConfig'));
        expect(content, contains('class DocsThemeExtension'));
        expect(content, contains('FontFamily.list(['));
        expect(content, contains("'--docs-shell-accent'"));
      });

      test(
        'responsive foundation centralizes canonical breakpoints and shell tokens',
        () {
          final responsive = _readOutput(
            outDir,
            'lib/theme/docs_responsive.dart',
          );
          final layout = _readOutput(
            outDir,
            'lib/layouts/api_docs_layout.dart',
          );
          final header = _readOutput(outDir, 'lib/components/docs_header.dart');
          final sidebar = _readOutput(
            outDir,
            'lib/components/docs_sidebar.dart',
          );
          final sidebarToggle = _readOutput(
            outDir,
            'lib/components/docs_sidebar_toggle.dart',
          );

          expect(responsive, contains('const docsCompactBreakpoint = 479;'));
          expect(responsive, contains('const docsMobileBreakpoint = 767;'));
          expect(responsive, contains('const docsContentBreakpoint = 959;'));
          expect(responsive, contains('const docsWideBreakpoint = 1180;'));
          expect(responsive, contains('StyleRule downCompact('));
          expect(responsive, contains('StyleRule downMobile('));
          expect(responsive, contains('StyleRule downContent('));
          expect(responsive, contains('StyleRule downWide('));
          expect(responsive, contains('docsResponsiveRootStyles() => ['));
          expect(responsive, contains("'--docs-shell-grid-gap'"));
          expect(responsive, contains("'--docs-shell-sidebar-width'"));
          expect(responsive, contains("'--docs-shell-toc-width'"));
          expect(responsive, contains("'--docs-shell-search-panel-width'"));
          expect(responsive, contains("'--docs-shell-drawer-width'"));

          expect(layout, contains("import '../theme/docs_responsive.dart';"));
          expect(layout, contains('...docsResponsiveRootStyles(),'));
          expect(layout, contains('downMobile(['));
          expect(layout, contains('downContent(['));
          expect(layout, contains('downWide(['));
          expect(layout, isNot(contains('MediaQuery.all(maxWidth: 767.px)')));
          expect(layout, isNot(contains('MediaQuery.all(maxWidth: 959.px)')));
          expect(layout, isNot(contains('MediaQuery.all(maxWidth: 1180.px)')));
          expect(header, contains("import '../theme/docs_responsive.dart';"));
          expect(header, contains('downMobile(['));
          expect(header, contains('downCompact(['));
          expect(sidebar, contains("import '../theme/docs_responsive.dart';"));
          expect(sidebar, contains('downContent(['));
          expect(
            sidebarToggle,
            contains("import '../theme/docs_responsive.dart';"),
          );
          expect(sidebarToggle, contains('downContent(['));
          expect(sidebar, isNot(contains('1023')));
          expect(sidebarToggle, isNot(contains('1024')));
        },
      );

      test('search index is generated for API pages', () {
        final content = _readOutput(outDir, 'web/generated/search_index.json');
        expect(content, contains('"version":4'));
        expect(content, contains('"entryCount"'));
        expect(content, contains('"/generated/search_pages.json"'));
        expect(content, contains('"/generated/search_sections.json"'));
        expect(content, contains('"/generated/search_sections_content.json"'));

        final pages = _readOutput(outDir, 'web/generated/search_pages.json');
        expect(pages, contains('"version":2'));
        expect(pages, contains('"/api/ex/Apple"'));
        expect(pages, contains('"Apple"'));

        final sections = _readOutput(
          outDir,
          'web/generated/search_sections.json',
        );
        expect(sections, contains('"version":3'));
        expect(sections, contains('"m1"'));
        expect(sections, contains('"m1()"'));

        final sectionContent = _readOutput(
          outDir,
          'web/generated/search_sections_content.json',
        );
        expect(sectionContent, contains('"version":4'));
        expect(sectionContent, contains('"m1"'));
      });

      test('api sidebar is generated as Dart, not TypeScript', () {
        final content = _readOutput(outDir, 'lib/generated/api_sidebar.dart');
        expect(content, contains('const apiSidebarGroups = <SidebarGroup>['));
        expect(content, contains("text: 'ex'"));
        expect(content, contains("text: 'Classes'"));
        expect(content, contains("text: 'Overview'"));
        expect(
          content,
          isNot(contains("import type { DefaultTheme } from 'vitepress'")),
        );
      });

      test(
        'api symbols are generated as pure Dart data for runtime linking',
        () {
          final content = _readOutput(outDir, 'lib/generated/api_symbols.dart');
          expect(content, contains('class ApiSymbolEntry'));
          expect(
            content,
            contains('const apiSymbolMap = <String, List<ApiSymbolEntry>>{'),
          );
          expect(content, contains("'Apple': ["));
          expect(content, contains("href: '/api/ex/Apple'"));
        },
      );

      test('api linker resolves runtime links against docs base path', () {
        final content = _readOutput(
          outDir,
          'lib/extensions/api_linker_extension.dart',
        );
        expect(content, contains("import '../docs_base.dart';"));
        expect(content, contains("'href': withDocsBasePath(entry.href)"));
        expect(content, contains('String? _normalizeMemberPath('));
        expect(
          content,
          contains("final qualifiedKey = '\$symbol.\$normalizedMember';"),
        );
      });

      test('base-path link extension normalizes content anchors', () {
        final content = _readOutput(
          outDir,
          'lib/extensions/base_path_link_extension.dart',
        );
        expect(content, contains("import '../docs_base.dart';"));
        expect(content, contains('return withDocsBasePath(href);'));
        expect(content, contains("'data-docs-nav-link': 'true'"));
      });

      test('API page strips VitePress-only syntax but keeps API content', () {
        final content = _readOutput(outDir, 'content/api/ex/Apple.md');
        expect(content, contains('# Apple'));
        expect(content, contains('member-signature'));
        expect(content, isNot(contains('<ApiBreadcrumb')));
        expect(content, isNot(contains('[[toc]]')));
      });

      test('members stay inline and no member subdirectory is created', () {
        expect(_dirExists(outDir, 'content/api/ex/Apple'), isFalse);
      });

      test('api layout recognizes library.md as the library overview page', () {
        final content = _readOutput(outDir, 'lib/layouts/api_docs_layout.dart');
        expect(content, contains("segments.last == 'library.md'"));
      });

      test('operator headings escape square brackets for markdown safety', () {
        final content = _readOutput(outDir, 'content/api/fake/SpecialList.md');
        expect(content, contains(r'### operator \[\]()'));
        expect(content, contains(r'### operator \[\]=()'));
      });

      test(
        'markdown backend does not emit HTML validator broken-link warnings',
        () {
          expect(_hasWarning(results, PackageWarning.brokenLink), isFalse);
        },
      );
    });

    group('guide generation and scaffold smoke', () {
      late final Folder outDir;

      setUpAll(() async {
        outDir = _createSystemTemp('jaspr_guide.');
        final dartdoc = _buildJasprDartdoc([], _testPackageWithDocsDir, outDir);
        await dartdoc.generateDocs();
      });

      tearDownAll(() {
        outDir.delete();
      });

      test('guide files are written under content/guide', () {
        expect(
          _outputExists(outDir, 'content/guide/getting-started.md'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'content/guide/advanced/configuration.md'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'content/guide/advanced/architecture.md'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'content/guide/recipes/testing-workflows.md'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'content/guide/recipes/pipeline-patterns.md'),
          isTrue,
        );
        expect(_outputExists(outDir, 'content/guide/ui/showcase.md'), isTrue);
      });

      test('guide sidebar is generated as Dart data', () {
        final content = _readOutput(outDir, 'lib/generated/guide_sidebar.dart');
        expect(content, contains('const guideSidebarGroups = <SidebarGroup>['));
        expect(content, contains('Getting Started'));
        expect(content, contains('Configuration'));
        expect(content, contains('Architecture'));
        expect(content, contains('Testing Workflows'));
        expect(content, contains('Pipeline Patterns'));
        expect(content, contains('UI Showcase'));
        expect(content, isNot(contains('export const guideSidebar')));
        expect(
          content.indexOf("text: 'Getting Started'"),
          lessThan(content.indexOf("text: 'Configuration'")),
        );
      });

      test('root preview entry boots the app shell and rewrites to overview', () {
        final content = _readOutput(outDir, 'web/index.html');
        expect(
          content,
          contains(
            '<meta http-equiv="refresh" content="0; url=guide/getting-started">',
          ),
        );
        expect(
          content,
          contains('window.location.replace("guide/getting-started");'),
        );
        expect(content, contains('<link rel="icon" href="favicon.svg"'));
        expect(
          content,
          contains('<link rel="stylesheet" href="generated/api_styles.css"'),
        );
        expect(content, contains('Redirecting to the documentation overview'));
        expect(_outputExists(outDir, 'web/404.html'), isTrue);
      });

      test('guide markdown remains clean for Jaspr consumption', () {
        final content = _readOutput(outDir, 'content/guide/getting-started.md');
        expect(content, contains('# Getting Started'));
        expect(content, isNot(contains('[[toc]]')));
        expect(content, isNot(contains('<ApiBreadcrumb')));
        expect(content, contains('```dart'));
        expect(content, isNot(contains('<<< snippets/hello.dart')));
        expect(content, contains('String greetingFor(String name)'));
        expect(content, isNot(contains('<<< snippets/pipeline_showcase.dart')));
        expect(content, contains('String buildPipelineDemo()'));
        expect(content, contains('```dartpad height=420 run=false'));
        expect(content, contains('```mermaid'));
        expect(content, contains('## UI Showcase'));
        expect(content, contains('### Outline Depth'));
      });

      test(
        'advanced guide keeps container syntax for runtime preprocessing',
        () {
          final content = _readOutput(
            outDir,
            'content/guide/advanced/configuration.md',
          );
          expect(content, contains(':::details Configuration Notes'));
          expect(content, contains(':::warning Caveat'));
          expect(content, contains(':::tip Recommended Setup'));
        },
      );

      test('expanded package generates multiple public library pages', () {
        expect(
          _outputExists(
            outDir,
            'content/api/test_package_with_docs/library.md',
          ),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'content/api/pipeline/library.md'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'content/api/showcase_ui/library.md'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'content/api/testing_support/library.md'),
          isTrue,
        );
      });

      test('search index includes guide pages and sections', () {
        final pages = _readOutput(outDir, 'web/generated/search_pages.json');
        expect(pages, contains('"/guide/getting-started"'));
        expect(pages, contains('Getting Started'));
        expect(pages, contains('"/guide/advanced/architecture"'));
        expect(pages, contains('"/guide/ui/showcase"'));
        expect(pages, contains('ShowcasePageSpec'));

        final sections = _readOutput(
          outDir,
          'web/generated/search_sections.json',
        );
        expect(sections, contains('"version":3'));
        expect(sections, contains('"installation"'));
        expect(sections, contains('"outline-depth"'));
        expect(sections, contains('"why-multiple-libraries"'));

        final sectionContent = _readOutput(
          outDir,
          'web/generated/search_sections_content.json',
        );
        expect(sectionContent, contains('Пример'));
        expect(sectionContent, contains('PrefixStage'));
        expect(sectionContent, contains('ShowcasePageSpec'));
      });

      test(
        'api symbols include qualified member links for inline guide linking',
        () {
          final content = _readOutput(outDir, 'lib/generated/api_symbols.dart');
          expect(content, contains("'GreetingScenario.smoke': ["));
          expect(
            content,
            contains(
              "href: '/api/testing_support/GreetingScenario#value-smoke'",
            ),
          );
        },
      );

      test('generated Jaspr scaffold passes pub get, analyze, and build', () {
        _runPubGetForScaffold(outDir.path);
        _runDartTool([
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ], outDir.path);
        _runDartTool(['analyze'], outDir.path);
        _runDartTool([
          'run',
          '/Users/belief/dev/projects/dartdoc-vitepress/tool/jaspr_scaffold_smoke.dart',
          outDir.path,
        ], '/Users/belief/dev/projects/dartdoc-vitepress');
      });
    });

    group('markdown link validation', () {
      late Folder pkgDir;
      late Folder outDir;

      tearDown(() {
        if (pkgDir.exists) {
          pkgDir.delete();
        }
        if (outDir.exists) {
          outDir.delete();
        }
      });

      test('relative markdown guide links resolve without warnings', () async {
        pkgDir = _copyPackageFixture(
          _testPackageWithDocsDir,
          'jaspr_links_ok.',
        );
        outDir = _createSystemTemp('jaspr_links_out_ok.');

        final guideFile = _resourceProvider.getFile(
          p.join(pkgDir.path, 'doc', 'getting-started.md'),
        );
        guideFile.writeAsStringSync(
          '${guideFile.readAsStringSync()}\n\nSee the [Configuration](advanced/configuration.md) guide.\n',
        );

        runPubGet(pkgDir.path);
        final dartdoc = _buildJasprDartdoc([], pkgDir, outDir);
        final results = await dartdoc.generateDocs();

        expect(_hasWarning(results, PackageWarning.brokenLink), isFalse);
      });

      test('broken guide links emit broken-link warnings', () async {
        pkgDir = _copyPackageFixture(
          _testPackageWithDocsDir,
          'jaspr_links_bad.',
        );
        outDir = _createSystemTemp('jaspr_links_out_bad.');

        final guideFile = _resourceProvider.getFile(
          p.join(pkgDir.path, 'doc', 'getting-started.md'),
        );
        guideFile.writeAsStringSync(
          '${guideFile.readAsStringSync()}\n\nBroken: [Missing Guide](/guide/missing-page).\n',
        );

        runPubGet(pkgDir.path);
        final dartdoc = _buildJasprDartdoc([], pkgDir, outDir);
        final results = await dartdoc.generateDocs();

        expect(_hasWarning(results, PackageWarning.brokenLink), isTrue);
      });
    }, timeout: Timeout.factor(4));
  });
}
