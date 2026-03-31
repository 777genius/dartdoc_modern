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

Folder _getFolder(String path) => _resourceProvider
    .getFolder(_pathContext.absolute(_pathContext.canonicalize(path)));

final _testPackageDir = _getFolder('testing/test_package');
final _testPackageWithDocsDir = _getFolder('testing/test_package_with_docs');

Dartdoc _buildJasprDartdoc(
    List<String> extraArgv, Folder pkgRoot, Folder outDir) {
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
  final file =
      _resourceProvider.getFile(p.normalize(p.join(outDir.path, relativePath)));
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

Folder _createSystemTemp(String prefix) => _resourceProvider
    .getFolder(Directory.systemTemp.createTempSync(prefix).path);

bool _hasWarning(DartdocResults results, PackageWarning warning) {
  return results.packageGraph.packageWarningCounter.countedWarnings.values
      .any((warningsByKind) => warningsByKind.containsKey(warning));
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

  final offlineResult = Process.runSync(
    Platform.resolvedExecutable,
    ['pub', 'get', '--offline'],
    workingDirectory: workingDirectory,
  );
  if (offlineResult.exitCode == 0) {
    return;
  }
  if (hasPackageConfig()) {
    return;
  }

  final onlineResult = Process.runSync(
    Platform.resolvedExecutable,
    ['pub', 'get'],
    workingDirectory: workingDirectory,
  );
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
      final optionSet = DartdocOptionRoot.fromOptionGenerators(
        'dartdoc',
        [createDartdocProgramOptions, createLoggingOptions],
        pubPackageMetaProvider,
      );
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
        expect(_outputExists(outDir, 'lib/main.server.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/main.client.dart'), isTrue);
        expect(_outputExists(outDir, 'web/index.html'), isTrue);
        expect(_outputExists(outDir, 'lib/theme/docs_theme.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/components/docs_search.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/components/docs_header.dart'), isTrue);
        expect(
          _outputExists(outDir, 'lib/components/docs_theme_toggle.dart'),
          isTrue,
        );
        expect(_outputExists(outDir, 'lib/components/docs_nav_link.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/components/docs_sidebar.dart'), isTrue);
        expect(_outputExists(outDir, 'lib/components/docs_sidebar_toggle.dart'), isTrue);
        expect(
          _outputExists(outDir, 'lib/components/docs_dartpad_runtime.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/components/docs_dartpad_runtime_stub.dart'),
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
          _outputExists(outDir, 'lib/components/docs_mermaid_runtime_stub.dart'),
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
          _outputExists(outDir, 'lib/layouts/api_docs_layout.dart'),
          isTrue,
        );
        expect(
          _outputExists(
              outDir, 'lib/template_engine/docs_template_engine.dart'),
          isTrue,
        );
        expect(_outputExists(outDir, 'content/index.md'), isTrue);
        expect(_outputExists(outDir, 'lib/generated/api_sidebar.dart'), isTrue);
        expect(
          _outputExists(outDir, 'lib/generated/guide_sidebar.dart'),
          isTrue,
        );
        expect(
          _outputExists(outDir, 'lib/generated/api_symbols.dart'),
          isTrue,
        );
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
        expect(_outputExists(outDir, 'content/api/ex/index.md'), isTrue);
        expect(_outputExists(outDir, 'content/api/ex/Apple.md'), isTrue);
      });

      test('main.server wires generated sidebars and stylesheet', () {
        final content = _readOutput(outDir, 'lib/main.server.dart');
        expect(content, contains("import 'package:jaspr/dom.dart';"));
        expect(content, contains("import 'app.dart';"));
        expect(content, contains("import 'main.server.options.dart';"));
        expect(
          content,
          contains("import 'template_engine/docs_template_engine.dart';"),
        );
        expect(content, contains("href: '/generated/api_styles.css'"));
        expect(content, contains("rel: 'stylesheet'"));
        expect(content, contains('Jaspr.initializeApp(options: defaultServerOptions);'));
        expect(content, contains("packageName: 'test_package'"));
        expect(content, contains('themePreset: themePreset'));
        expect(content, contains('templateEngine: DocsTemplateEngine()'));
        expect(
          content,
          contains("const themeName = String.fromEnvironment('DOCS_THEME'"),
        );
        expect(
          content,
          contains('DocsThemePresetX.parse(themeName)'),
        );
      });

      test('shared app builder is reused by server and client entrypoints', () {
        final app = _readOutput(outDir, 'lib/app.dart');
        final client = _readOutput(outDir, 'lib/main.client.dart');

        expect(app, contains('Component buildDocsApp({'));
        expect(app, contains('ContentApp('));
        expect(app, contains('TemplateEngine? templateEngine,'));
        expect(app, contains('templateEngine: templateEngine,'));
        expect(
          app,
          isNot(contains("import 'template_engine/docs_template_engine.dart';")),
        );
        expect(app, contains("import 'components/docs_header.dart';"));
        expect(app, contains("import 'components/docs_sidebar.dart';"));
        expect(app, contains("import 'components/docs_theme_toggle.dart';"));
        expect(app, contains("import 'generated/api_sidebar.dart' as api;"));
        expect(app, contains("import 'generated/guide_sidebar.dart' as guide;"));
        expect(app, contains('header: DocsHeader('));
        expect(app, contains('const DocsThemeToggle()'));
        expect(app, contains('sidebar: DocsSidebar('));
        expect(app, contains('DocsSidebarGroup('));
        expect(app, contains('DocsSidebarItem('));
        expect(client, contains("import 'main.client.options.dart';"));
        expect(client, contains('Jaspr.initializeApp(options: defaultClientOptions);'));
        expect(client, contains('runApp(const ClientApp());'));
        expect(client, isNot(contains("import 'app.dart';")));
        expect(client, isNot(contains('buildDocsApp(')));
      });

      test('custom layout wires feature runtimes', () {
        final content = _readOutput(outDir, 'lib/layouts/api_docs_layout.dart');
        final header = _readOutput(outDir, 'lib/components/docs_header.dart');
        final search = _readOutput(outDir, 'lib/components/docs_search.dart');
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
        final themeToggle = _readOutput(
          outDir,
          'lib/components/docs_theme_toggle.dart',
        );
        final navLink = _readOutput(outDir, 'lib/components/docs_nav_link.dart');
        final sidebar = _readOutput(outDir, 'lib/components/docs_sidebar.dart');
        final sidebarToggle = _readOutput(
          outDir,
          'lib/components/docs_sidebar_toggle.dart',
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
        expect(content, contains("import '../components/docs_search.dart';"));
        expect(
          content,
          contains("import '../components/docs_dartpad_runtime.dart';"),
        );
        expect(
          content,
          contains("import '../components/docs_mermaid_runtime.dart';"),
        );
        expect(header, contains('class DocsHeader extends StatelessComponent'));
        expect(header, contains('const DocsSidebarToggle()'));
        expect(header, contains("classes: 'header-title'"));
        expect(header, contains('DocsNavLink('));
        expect(themeToggle, contains('class DocsThemeToggle extends StatefulComponent'));
        expect(themeToggle, contains("id: 'docs-theme-script'"));
        expect(themeToggle, contains("window.localStorage.getItem('jaspr:theme')"));
        expect(
          themeToggle,
          contains("document.documentElement.setAttribute('data-theme', resolvedTheme)"),
        );
        expect(themeToggle, contains("classes: 'theme-toggle'"));
        expect(themeToggle, contains("'data-docs-theme-toggle': ''"));
        expect(content, contains("import '../components/docs_nav_link.dart';"));
        expect(search, contains("import 'docs_navigation_runtime.dart';"));
        expect(content, contains('const DocsSearchShell()'));
        expect(content, contains('const DocsDartPadRuntime()'));
        expect(content, contains('const DocsMermaidRuntime()'));
        expect(content, contains('DocsNavLink('));
        expect(content, isNot(contains('case final Header header')));
        expect(content, isNot(contains('case final Sidebar sidebar')));
        expect(search, contains('@client'));
        expect(search, contains('class DocsSearchShell extends StatefulComponent'));
        expect(search, contains('const DocsNavigationRuntime()'));
        expect(search, contains("classes: 'search-launcher'"));
        expect(search, contains("'data-docs-search-launcher': ''"));
        expect(search, contains('docs-search-overlay'));
        expect(search, contains("'data-docs-search-overlay': ''"));
        expect(search, contains('http.get(Uri.parse(path))'));
        expect(search, contains("import 'docs_nav_link.dart';"));
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
        expect(search, contains('node.click();'));
        expect(search, contains('docs-search-footer'));
        expect(search, contains('_latestQueryToken'));
        expect(search, contains("classes: 'search-launcher-shortcut'"));
        expect(search, contains('_focusableNodesWithin('));
        expect(search, contains('docs.search.manifest.v4'));
        expect(search, contains('docs.search.pages:'));
        expect(search, contains("'role': 'dialog'"));
        expect(search, contains("event.key == 'ArrowDown'"));
        expect(
          navigationRuntime,
          contains("export 'docs_navigation_runtime_stub.dart'"),
        );
        expect(
          navigationRuntimeStub,
          contains('class DocsNavigationRuntime extends StatelessComponent'),
        );
        expect(
          navigationRuntimeWeb,
          contains('class DocsNavigationRuntime extends StatefulComponent'),
        );
        expect(navigationRuntimeWeb, contains("a[data-docs-nav-link]"));
        expect(navigationRuntimeWeb, contains("web.window.history.pushState"));
        expect(navigationRuntimeWeb, contains("web.DOMParser().parseFromString"));
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
          contains("web.window.dispatchEvent(web.CustomEvent('docs:navigation'))"),
        );
        expect(navLink, contains('class DocsNavLink extends StatelessComponent'));
        expect(navLink, contains("'data-docs-nav-link': 'true'"));
        expect(navLink, contains('Router.maybeOf(context)'));
        expect(navLink, contains('router.preload(to)'));
        expect(navLink, contains('router.push(to, extra: extra)'));
        expect(navLink, contains('onNavigate?.call()'));
        expect(navLink, contains('_isModifiedClick('));
        expect(navLink, contains("value.startsWith('https://')"));
        expect(sidebar, contains('class DocsSidebar extends StatelessComponent'));
        expect(sidebar, contains("import 'package:jaspr_content/jaspr_content.dart';"));
        expect(sidebar, contains("attributes: {'id': 'docs-sidebar'}"));
        expect(sidebar, contains("classes: 'sidebar-close'"));
        expect(sidebar, contains("'data-docs-sidebar-close': 'true'"));
        expect(sidebar, contains('DocsNavLink('));
        expect(sidebarToggle, contains('class DocsSidebarToggle extends StatefulComponent'));
        expect(sidebarToggle, contains("'data-docs-sidebar-toggle': ''"));
        expect(sidebarToggle, contains("aria-controls': 'docs-sidebar'"));
        expect(sidebarToggle, contains("sidebar.classList.add('open')"));
        expect(sidebarToggle, contains("web.document.body?.style.overflow = 'hidden'"));
        expect(dartPadRuntime, contains("export 'docs_dartpad_runtime_stub.dart'"));
        expect(
          dartPadRuntimeWeb,
          contains('class DocsDartPadRuntime extends StatefulComponent'),
        );
        expect(dartPadRuntimeWeb, contains('candidate.contentWindow'));
        expect(dartPadRuntimeWeb, contains('navigator.clipboard'));
        expect(dartPadRuntimeWeb, contains('https://dartpad.dev'));
        expect(mermaidRuntime, contains("export 'docs_mermaid_runtime_stub.dart'"));
        expect(
          mermaidRuntimeWeb,
          contains('class DocsMermaidRuntime extends StatefulComponent'),
        );
        expect(mermaidRuntimeWeb, contains("@JS('mermaid')"));
        expect(mermaidRuntimeWeb, contains('callMethod<JSPromise<JSObject>>('));
        expect(mermaidRuntimeWeb, contains("querySelectorAll('.mermaid-diagram')"));
        expect(mermaidRuntimeWeb, contains("addEventListener('docs:navigation'"));
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
        expect(content, contains('extension DocsThemePresetX on DocsThemePreset'));
        expect(content, contains('static DocsThemePreset parse(String value)'));
        expect(content, contains('class DocsThemeConfig'));
        expect(content, contains('class DocsThemeExtension'));
        expect(content, contains('FontFamily.list(['));
        expect(content, contains("'--docs-shell-accent'"));
      });

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

        final sections =
            _readOutput(outDir, 'web/generated/search_sections.json');
        expect(sections, contains('"version":3'));
        expect(sections, contains('"m1"'));
        expect(sections, contains('"m1()"'));

        final sectionContent =
            _readOutput(outDir, 'web/generated/search_sections_content.json');
        expect(sectionContent, contains('"version":4'));
        expect(sectionContent, contains('"m1"'));
      });

      test('api sidebar is generated as Dart, not TypeScript', () {
        final content = _readOutput(outDir, 'lib/generated/api_sidebar.dart');
        expect(content, contains('const apiSidebarGroups = <SidebarGroup>['));
        expect(content, contains("SidebarItem(text: 'ex'"));
        expect(
          content,
          isNot(contains("import type { DefaultTheme } from 'vitepress'")),
        );
      });

      test('api symbols are generated as pure Dart data for runtime linking', () {
        final content = _readOutput(outDir, 'lib/generated/api_symbols.dart');
        expect(content, contains('class ApiSymbolEntry'));
        expect(content, contains('const apiSymbolMap = <String, List<ApiSymbolEntry>>{'));
        expect(content, contains("'Apple': ["));
        expect(content, contains("href: '/api/ex/Apple'"));
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

      test('markdown backend does not emit HTML validator broken-link warnings',
          () {
        expect(_hasWarning(results, PackageWarning.brokenLink), isFalse);
      });
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
            _outputExists(outDir, 'content/guide/getting-started.md'), isTrue);
        expect(
          _outputExists(outDir, 'content/guide/advanced/configuration.md'),
          isTrue,
        );
      });

      test('guide sidebar is generated as Dart data', () {
        final content = _readOutput(outDir, 'lib/generated/guide_sidebar.dart');
        expect(content, contains('const guideSidebarGroups = <SidebarGroup>['));
        expect(content, contains('Getting Started'));
        expect(content, contains('Configuration'));
        expect(content, isNot(contains('export const guideSidebar')));
        expect(
          content.indexOf("SidebarItem(text: 'Getting Started'"),
          lessThan(content.indexOf("SidebarItem(text: 'Configuration'")),
        );
      });

      test('root preview entry boots the app shell and rewrites to overview', () {
        final content = _readOutput(outDir, 'web/index.html');
        expect(content, contains('<meta http-equiv="refresh" content="0; url=/guide/getting-started">'));
        expect(content, contains('window.location.replace("/guide/getting-started");'));
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
        expect(content, contains('```dartpad height=420 run=false'));
        expect(content, contains('```mermaid'));
      });

      test('advanced guide keeps container syntax for runtime preprocessing',
          () {
        final content =
            _readOutput(outDir, 'content/guide/advanced/configuration.md');
        expect(content, contains(':::details Configuration Notes'));
        expect(content, contains(':::warning Caveat'));
      });

      test('search index includes guide pages and sections', () {
        final pages = _readOutput(outDir, 'web/generated/search_pages.json');
        expect(pages, contains('"/guide/getting-started"'));
        expect(pages, contains('Getting Started'));

        final sections =
            _readOutput(outDir, 'web/generated/search_sections.json');
        expect(sections, contains('"version":3'));
        expect(sections, contains('"installation"'));

        final sectionContent =
            _readOutput(outDir, 'web/generated/search_sections_content.json');
        expect(sectionContent, contains('Пример'));
      });

      test('generated Jaspr scaffold passes pub get, analyze, and build', () {
        _runPubGetForScaffold(outDir.path);
        _runDartTool(
          ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
          outDir.path,
        );
        _runDartTool(['analyze'], outDir.path);
        _runDartTool(
          [
            'run',
            '/Users/belief/dev/projects/dartdoc-vitepress/tool/jaspr_scaffold_smoke.dart',
            outDir.path,
          ],
          '/Users/belief/dev/projects/dartdoc-vitepress',
        );
      });
    });
  });
}
