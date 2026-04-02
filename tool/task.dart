// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dartdoc_vitepress/src/package_meta.dart';
import 'package:path/path.dart' as path;
import 'package:sass/sass.dart' as sass;

import 'src/flutter_repo.dart';
import 'src/io_utils.dart' as io_utils;
import 'src/subprocess_launcher.dart';
import 'src/warnings_collection.dart';

void main(List<String> args) async {
  var parser = ArgParser()
    ..addCommand('analyze')
    ..addCommand('buildbot')
    ..addCommand('clean')
    ..addCommand('compare')
    ..addCommand('help')
    ..addCommand('test')
    ..addCommand('try-publish')
    ..addCommand('validate');
  var buildCommand = parser.addCommand('build')
    ..addFlag('debug', help: 'build unoptimized JavaScript');
  var docCommand = parser.addCommand('doc')
    ..addOption('name', help: 'package name')
    ..addOption('version', help: 'package version')
    ..addFlag('stats', help: 'print runtime stats');
  var serveCommand = parser.addCommand('serve')
    ..addOption('name')
    ..addOption('version');

  var results = parser.parse(args);
  var commandResults = results.command;
  if (commandResults == null) {
    return;
  }

  buildUsage = buildCommand.usage;
  docUsage = docCommand.usage;
  serveUsage = serveCommand.usage;

  return await switch (commandResults.name) {
    'analyze' => runAnalyze(commandResults),
    'build' => runBuild(commandResults),
    'buildbot' => runBuildbot(),
    'clean' => runClean(),
    'compare' => runCompare(commandResults),
    'doc' => runDoc(commandResults),
    'help' => runHelp(commandResults),
    'serve' => runServe(commandResults),
    'test' => runTest(),
    'try-publish' => runTryPublish(),
    'validate' => runValidate(commandResults),
    _ => throw ArgumentError(),
  };
}

late String buildUsage;
late String docUsage;
late String serveUsage;

Directory get testPackage =>
    Directory(path.joinAll(['testing', 'test_package']));

Directory get testPackageExperiments =>
    Directory(path.joinAll(['testing', 'test_package_experiments']));

final class _JasprPreviewWorkspace {
  _JasprPreviewWorkspace({
    required this.outputDir,
    required this.pubCacheDir,
    required this.theme,
    required this.basePath,
  });

  final Directory outputDir;
  final Directory pubCacheDir;
  final String theme;
  final String basePath;

  void dispose() {
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    if (pubCacheDir.existsSync()) {
      pubCacheDir.deleteSync(recursive: true);
    }
  }
}

String get _pathListSeparator => Platform.isWindows ? ';' : ':';

String _prependPathEntry(String entry, String? existingPath) => [
      entry,
      if (existingPath != null && existingPath.isNotEmpty) existingPath,
    ].join(_pathListSeparator);

String _bashPath(List<String> segments) => path.posix.joinAll(segments);

Future<void> runAnalyze(ArgResults commandResults) async {
  for (var target in commandResults.rest) {
    await switch (target) {
      'package' => analyzePackage(),
      'test-packages' => analyzeTestPackages(),
      _ => throw UnimplementedError('Unknown analyze target: "$target"'),
    };
  }
}

Future<void> analyzePackage() async =>
    await SubprocessLauncher('analyze').runStreamedDartCommand(
      ['analyze', '--fatal-infos', '.'],
    );

Future<void> analyzeTestPackages() async {
  var testPackagePaths = [
    testPackage.path,
    if (Platform.version.contains('dev')) testPackageExperiments.path,
  ];
  for (var testPackagePath in testPackagePaths) {
    await SubprocessLauncher('pub-get').runStreamedDartCommand(
      ['pub', 'get'],
      workingDirectory: testPackagePath,
    );
    await SubprocessLauncher('analyze-test-package').runStreamedDartCommand(
      // TODO(srawlins): Analyze the whole directory by ignoring the pubspec
      // reports.
      ['analyze', 'lib'],
      workingDirectory: testPackagePath,
    );
  }
}

Future<void> _buildHelp() async {
  print('''
Usage:
dart tool/task.dart build [renderers|dartdoc-options|web]
$buildUsage
''');
}

Future<void> runBuild(ArgResults commandResults) async {
  if (commandResults.rest.isEmpty) {
    await buildAll();
  }
  var debug = (commandResults['debug'] ?? false) as bool;
  for (var target in commandResults.rest) {
    await switch (target) {
      'renderers' => buildRenderers(),
      'dartdoc-options' => buildDartdocOptions(),
      'web' => buildWeb(debug: debug),
      _ => throw UnimplementedError('Unknown build target: "$target"'),
    };
  }
}

Future<void> buildAll() async {
  if (Platform.isWindows) {
    // Built files only need to be built on Linux and MacOS, as there are path
    // issues with Windows.
    return;
  }
  await buildWeb();
  await buildRenderers();
  await buildDartdocOptions();
}

Future<void> buildRenderers() async => await SubprocessLauncher('build')
    .runStreamedDartCommand([path.join('tool', 'mustachio', 'builder.dart')]);

Future<void> buildDartdocOptions() async {
  var dartdocOptions = File('dartdoc_options.yaml');
  await dartdocOptions.writeAsString('''dartdoc:
  linkToSource:
    root: '.'
    uriTemplate: 'https://github.com/777genius/dartdoc_vitepress/blob/main/%f%#L%l%'
''');
}

Future<void> buildWeb({bool debug = false}) async {
  await SubprocessLauncher('build').runStreamedDartCommand([
    'compile',
    'js',
    '--output=lib/resources/docs.dart.js',
    'web/docs.dart',
    if (debug) '--enable-asserts',
    debug ? '-O0' : '-O4',
  ]);
  _delete(File('lib/resources/docs.dart.js.deps'));

  final compileResult = sass.compileToResult('web/styles/styles.scss',
      style: debug ? sass.OutputStyle.expanded : sass.OutputStyle.compressed);
  if (compileResult.css.isNotEmpty) {
    File('lib/resources/styles.css')
        .writeAsStringSync('${compileResult.css}\n');
  } else {
    throw StateError('Compiled CSS was empty.');
  }

  var compileSig =
      await _calcFilesSig(Directory('web'), extensions: {'.dart', '.scss'});
  File(path.join('web', 'sig.txt')).writeAsStringSync('$compileSig\n');
}

/// Delete the given file entity reference.
void _delete(FileSystemEntity entity) {
  if (entity.existsSync()) {
    print('deleting ${entity.path}');
    entity.deleteSync(recursive: true);
  }
}

/// Yields all of the trimmed lines of all of the files in [dir] with
/// one of the specified [extensions].
Stream<String> _fileLines(Directory dir, {required Set<String> extensions}) {
  var files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => extensions.contains(path.extension(file.path)))
      .sorted((a, b) => compareAsciiLowerCase(a.path, b.path));

  return Stream.fromIterable([
    for (var file in files)
      for (var line in file.readAsLinesSync()) line.trim(),
  ]);
}

Future<void> runBuildbot() async {
  await _section('Analyze test packages', analyzeTestPackages);
  await _section('Analyze package', analyzePackage);
  await _section('Validate format', validateFormat);
  await _section('Validate build', validateBuild);
  await _section('Validate Jaspr launch', validateJasprLaunch);
  await _section('Run try publish', runTryPublish);
  await _section('Run test', runTest);
  await _section('Validate dartdoc docs', validateDartdocDocs);
}

Future<void> _section(String title, Future<void> Function() body) async {
  if (Platform.environment['GITHUB_ACTIONS'] == 'true') {
    print('::group::$title');
    try {
      await body();
    } catch (e) {
      print('::error::$e');
      rethrow;
    } finally {
      print('::endgroup::');
    }
  } else {
    await body();
  }
}

Future<void> runClean() async {
  // This involves deleting things, so be careful.
  if (!File(path.join('tool', 'task.dart')).existsSync()) {
    throw FileSystemException('Wrong CWD, run from root of dartdoc package');
  }
  const pubDataFileNames = {'.dart_tool', '.packages', 'pubspec.lock'};
  var nonRootPubData = Directory('.')
      .listSync(recursive: true)
      .where((e) => path.dirname(e.path) != '.')
      .where((e) => pubDataFileNames.contains(path.basename(e.path)));
  for (var e in nonRootPubData) {
    e.deleteSync(recursive: true);
  }
}

Future<void> runCompare(ArgResults commandResults) async {
  if (commandResults.rest.length != 1) {
    throw ArgumentError('"compare" command requires a single target.');
  }
  var target = commandResults.rest.single;
  await switch (target) {
    'flutter-warnings' => compareFlutterWarnings(),
    'sdk-warnings' => compareSdkWarnings(),
    _ => throw UnimplementedError('Unknown compare target: "$target"'),
  };
}

Future<void> compareFlutterWarnings() async {
  var originalDartdocFlutter =
      Directory.systemTemp.createTempSync('dartdoc-comparison-flutter');
  var originalDartdoc = await _createComparisonDartdoc();
  var envCurrent = createThrowawayPubCache();
  var envOriginal = createThrowawayPubCache();
  var currentDartdocFlutterBuild = _docFlutter(
    flutterPath: flutterDir.path,
    cwd: Directory.current.path,
    env: envCurrent,
    label: 'docs-current',
  );
  var originalDartdocFlutterBuild = _docFlutter(
    flutterPath: originalDartdocFlutter.path,
    cwd: originalDartdoc,
    env: envOriginal,
    label: 'docs-original',
  );
  var currentDartdocWarnings = _collectWarnings(
    messages: await currentDartdocFlutterBuild,
    tempPath: flutterDir.absolute.path,
    branch: 'HEAD',
    pubDir: envCurrent['PUB_CACHE'],
  );
  var originalDartdocWarnings = _collectWarnings(
    messages: await originalDartdocFlutterBuild,
    tempPath: originalDartdocFlutter.absolute.path,
    branch: _dartdocOriginalBranch,
    pubDir: envOriginal['PUB_CACHE'],
  );

  print(originalDartdocWarnings.warningDeltaText(
      'Flutter repo', currentDartdocWarnings));

  if (Platform.environment['SERVE_FLUTTER'] == '1') {
    var launcher = SubprocessLauncher('serve-flutter-docs');
    await launcher.runStreamed(Platform.resolvedExecutable, ['pub', 'get']);
    var original = launcher.runStreamed(Platform.resolvedExecutable, [
      'pub',
      'global',
      'run',
      'dhttpd',
      '--port',
      '9000',
      '--path',
      path.join(originalDartdocFlutter.absolute.path, 'dev', 'docs', 'doc'),
    ]);
    var current = launcher.runStreamed(Platform.resolvedExecutable, [
      'pub',
      'global',
      'run',
      'dhttpd',
      '--port',
      '9001',
      '--path',
      path.join(flutterDir.absolute.path, 'dev', 'docs', 'doc'),
    ]);
    await [original, current].wait;
  }
}

Future<void> runDoc(ArgResults commandResults) async {
  if (commandResults.rest.length != 1) {
    throw ArgumentError('"doc" command requires a single target.');
  }
  var target = commandResults.rest.single;
  var stats = commandResults['stats'] as bool;
  await switch (target) {
    'flutter' => docFlutter(withStats: stats),
    'help' => _docHelp(),
    'package' => _docPackage(commandResults, withStats: stats),
    'sdk' => docSdk(withStats: stats),
    'testing-package' => docTestingPackage(withStats: stats),
    _ => throw UnimplementedError('Unknown doc target: "$target"'),
  };
}

Future<void> docFlutter({bool withStats = false}) async {
  print('building flutter docs into: ${flutterDir.path}');
  var env = createThrowawayPubCache();
  await _docFlutter(
    flutterPath: flutterDir.path,
    cwd: Directory.current.path,
    env: env,
    label: 'docs',
    withStats: withStats,
  );
}

Future<Iterable<Map<String, Object?>>> _docFlutter({
  required String flutterPath,
  required String cwd,
  required Map<String, String> env,
  String? label,
  bool withStats = false,
}) async {
  var flutterRepo = await FlutterRepo.copyFromExistingFlutterRepo(
      await cleanFlutterRepo, flutterPath, env, label);
  await _patchFlutterApiDocsRunner(flutterPath);
  var snippetsPath = path.join(flutterPath, 'dev', 'snippets');
  var snippetsOutPath =
      path.join(flutterPath, 'bin', 'cache', 'artifacts', 'snippets');
  print('building snippets tool executable...');
  Directory(snippetsOutPath).createSync(recursive: true);
  await flutterRepo.launcher.runStreamed(
    flutterRepo.flutterCmd,
    ['pub', 'get'],
    workingDirectory: path.join(snippetsPath),
  );
  await flutterRepo.launcher.runStreamed(
    flutterRepo.dartCmd,
    ['compile', 'exe', '-o', '$snippetsOutPath/snippets', 'bin/snippets.dart'],
    workingDirectory: path.join(snippetsPath),
  );
  // TODO(jcollins-g): flutter's dart SDK pub tries to precompile the universe
  // when using -spath.  Why?
  await flutterRepo.launcher.runStreamed(
    flutterRepo.flutterCmd,
    ['pub', 'global', 'activate', '-spath', '.', '-x', 'dartdoc_vitepress'],
    workingDirectory: cwd,
  );
  await flutterRepo.launcher.runStreamed(
    flutterRepo.flutterCmd,
    ['pub', 'get'],
    workingDirectory: path.join(flutterPath, 'dev', 'tools'),
  );
  return await flutterRepo.launcher.runStreamed(
    flutterRepo.dartCmd,
    [
      '--disable-dart-dev',
      '--enable-asserts',
      path.join(
        'dev',
        'tools',
        'create_api_docs.dart',
      ),
      '--json',
    ],
    workingDirectory: flutterPath,
    withStats: withStats,
  );
}

Future<void> _patchFlutterApiDocsRunner(String flutterPath) async {
  final createApiDocs = File(
    path.join(flutterPath, 'dev', 'tools', 'create_api_docs.dart'),
  );
  final contents = await createApiDocs.readAsString();

  var patched = contents.replaceFirst(
    r"r'^(?<name>dartdoc) (?<version>[^\s]+)'",
    r"r'^(?<name>dartdoc(?:_vitepress)?) (?<version>[^\s]+)'",
  );
  patched = patched.replaceFirst("'dartdoc',", "'dartdoc_vitepress',");

  if (patched == contents) {
    throw StateError(
      'Failed to patch Flutter API docs runner for dartdoc_vitepress.',
    );
  }

  await createApiDocs.writeAsString(patched);
}

final Directory flutterDir =
    Directory.systemTemp.createTempSync('flutter').absolute;

Future<void> _docHelp() async {
  print('''
Usage:
dart tool/task.dart doc [flutter|package|sdk|testing-package]
$docUsage
''');
}

Future<void> _docPackage(
  ArgResults commandResults, {
  bool withStats = false,
}) async {
  var name = commandResults['name'] as String;
  var version = commandResults['version'] as String?;
  await docPackage(name: name, version: version, withStats: withStats);
}

Future<String> docPackage({
  required String name,
  required String? version,
  bool withStats = false,
}) async {
  var env = createThrowawayPubCache();
  var versionContext = version == null ? '' : '-$version';
  var launcher = SubprocessLauncher('build-$name$versionContext', env);
  await launcher.runStreamedDartCommand([
    'pub',
    'cache',
    'add',
    if (version != null) ...['-v', version],
    name,
  ]);
  var cache = Directory(path.join(env['PUB_CACHE']!, 'hosted', 'pub.dev'));
  // The pub package should be predictably in a location like this.
  var pubPackageDirOrig =
      cache.listSync().firstWhere((e) => e.path.contains('/$name-'));
  var pubPackageDir = Directory.systemTemp.createTempSync(name);
  io_utils.copy(pubPackageDirOrig, pubPackageDir);

  var executable = Platform.executable;
  var arguments = [
    '--enable-asserts',
    path.join(Directory.current.absolute.path, 'bin', 'dartdoc_vitepress.dart'),
    '--link-to-remote',
    '--show-progress',
    '--show-stats',
    '--no-validate-links',
  ];
  Map<String, String>? environment;

  if (pubPackageMetaProvider
      .fromDir(PhysicalResourceProvider.INSTANCE.getFolder(pubPackageDir.path))!
      .requiresFlutter) {
    var flutterRepo =
        await FlutterRepo.fromExistingFlutterRepo(await cleanFlutterRepo);
    executable = flutterRepo.cacheDart;
    environment = flutterRepo.env;
  }
  await launcher.runStreamed(
    executable,
    ['pub', 'get'],
    environment: environment,
    workingDirectory: pubPackageDir.absolute.path,
  );
  await launcher.runStreamed(
    executable,
    // Add the `--json` flag for the support in `runStreamed` to tease out
    // data and messages. This flag allows the [runCompare] tasks to interpret
    // data from stdout as structured data, in order to compare the dartdoc
    // outputs of two commands. We add it here, but exclude it from the
    // "Quickly re-run" text below, as that command is for human consumption.
    [...arguments, '--json'],
    workingDirectory: pubPackageDir.absolute.path,
    environment: environment,
    withStats: withStats,
  );
  if (withStats) {
    (executable, arguments) =
        SubprocessLauncher.wrapWithTime(executable, arguments);
  }
  print('Quickly re-run doc generation with:');
  print(
    '    pushd ${pubPackageDir.absolute.path} ;'
    ' "$executable" ${arguments.map((a) => '"$a"').join(' ')} ;'
    ' popd',
  );
  return path.join(pubPackageDir.absolute.path, 'doc', 'api');
}

Future<void> docSdk({bool withStats = false}) async => _docSdk(
      sdkDocsPath: _sdkDocsDir.path,
      dartdocPath: Directory.current.path,
      withStats: withStats,
    );

/// Creates a throwaway pub cache and returns the environment variables
/// necessary to use it.
Map<String, String> createThrowawayPubCache() {
  var pubCache = Directory.systemTemp.createTempSync('pubcache');
  var pubCacheBin = Directory(path.join(pubCache.path, 'bin'));
  pubCacheBin.createSync();
  return Map.fromIterables([
    'PUB_CACHE',
    'PATH',
  ], [
    pubCache.path,
    _prependPathEntry(pubCacheBin.path, Platform.environment['PATH']),
  ]);
}

Future<String> docTestingPackage({
  bool withStats = false,
}) async {
  var testPackagePath = testPackage.absolute.path;
  var launcher = SubprocessLauncher('doc-test-package');
  await launcher.runStreamedDartCommand(
    ['pub', 'get'],
    workingDirectory: testPackagePath,
  );
  var outputPath = _testingPackageDocsDir.absolute.path;
  await launcher.runStreamedDartCommand(
    [
      '--enable-asserts',
      path.join(Directory.current.absolute.path, 'bin', 'dartdoc_vitepress.dart'),
      '--output',
      outputPath,
      '--include-source',
      '--json',
      '--link-to-remote',
      '--pretty-index-json',
    ],
    workingDirectory: testPackagePath,
    withStats: withStats,
  );

  if (withStats && (Platform.isLinux || Platform.isMacOS)) {
    // Prints all files in `outputPath`, newline-separated.
    var findResult = Process.runSync('find', [outputPath, '-type', 'f']);
    var fileCount = (findResult.stdout as String).split('\n').length;
    var diskUsageResult = Process.runSync('du', ['-sh', outputPath]);
    // Output looks like
    // 146M    /var/folders/72/ltck4q353hsg3bn8kpkg7f84005w15/T/sdkdocsHcquiB
    var diskUsageNumber =
        (diskUsageResult.stdout as String).trim().split(RegExp('\\s+')).first;
    print('Generated $fileCount files amounting to $diskUsageNumber.');
  }

  return outputPath;
}

final Directory _testingPackageDocsDir =
    Directory.systemTemp.createTempSync('testing_package');

Future<void> compareSdkWarnings() async {
  var originalDartdocSdkDocs =
      Directory.systemTemp.createTempSync('dartdoc-comparison-sdkdocs');
  var originalDartdoc = await _createComparisonDartdoc();
  var sdkDocsPath =
      Directory.systemTemp.createTempSync('sdkdocs').absolute.path;
  var currentDartdocSdkBuild = _docSdk(
    sdkDocsPath: sdkDocsPath,
    dartdocPath: Directory.current.path,
  );
  var originalDartdocSdkBuild = _docSdk(
    sdkDocsPath: originalDartdocSdkDocs.path,
    dartdocPath: originalDartdoc,
  );
  var currentDartdocWarnings = _collectWarnings(
    messages: await currentDartdocSdkBuild,
    tempPath: sdkDocsPath,
    branch: 'HEAD',
  );
  var originalDartdocWarnings = _collectWarnings(
    messages: await originalDartdocSdkBuild,
    tempPath: originalDartdocSdkDocs.absolute.path,
    branch: _dartdocOriginalBranch,
  );

  print(originalDartdocWarnings.warningDeltaText(
      'SDK docs', currentDartdocWarnings));
}

Future<Iterable<Map<String, Object?>>> _docSdk({
  required String sdkDocsPath,
  required String dartdocPath,
  bool withStats = false,
}) async {
  var launcher = SubprocessLauncher('build-sdk-docs');
  await launcher
      .runStreamedDartCommand(['pub', 'get'], workingDirectory: dartdocPath);
  var output = await launcher.runStreamedDartCommand(
    [
      '--enable-asserts',
      path.join('bin', 'dartdoc_vitepress.dart'),
      '--output',
      sdkDocsPath,
      '--sdk-docs',
      '--json',
      '--show-progress',
      // Use some local assets for the header and footers, to override the SDK
      // values, from an options file, which includes not-shipped files.
      '--header',
      'lib/resources/blank.txt',
      '--footer',
      'lib/resources/blank.txt',
      '--footer-text',
      'lib/resources/blank.txt',
    ],
    workingDirectory: dartdocPath,
    withStats: withStats,
  );
  if (withStats && (Platform.isLinux || Platform.isMacOS)) {
    var diskUsageResult = Process.runSync('du', ['-sh', sdkDocsPath]);
    // Output looks like
    // 146M    /var/folders/72/ltck4q353hsg3bn8kpkg7f84005w15/T/sdkdocsHcquiB
    var diskUsageNumber =
        (diskUsageResult.stdout as String).trim().split(RegExp('\\s+')).first;

    // Prints all files in `sdkDocsPath`, newline-separated.
    var findResult = Process.runSync('find', [sdkDocsPath, '-type', 'f']);
    var fileCount = (findResult.stdout as String).split('\n').length;
    print('Generated $fileCount files amounting to $diskUsageNumber.');
  }
  return output;
}

/// Creates a clean version of dartdoc (based on the current directory, assumed
/// to be a git repository).
///
/// Uses [_dartdocOriginalBranch] to checkout a branch or tag.
Future<String> _createComparisonDartdoc() async {
  var launcher = SubprocessLauncher('create-comparison-dartdoc');
  var dartdocClean = Directory.systemTemp.createTempSync('dartdoc-comparison');
  await launcher
      .runStreamed('git', ['clone', Directory.current.path, dartdocClean.path]);
  await launcher.runStreamed('git', ['checkout', _dartdocOriginalBranch],
      workingDirectory: dartdocClean.path);
  await launcher.runStreamed(Platform.resolvedExecutable, ['pub', 'get'],
      workingDirectory: dartdocClean.path);
  return dartdocClean.path;
}

/// Version of dartdoc we should use when making comparisons.
String get _dartdocOriginalBranch {
  var branch = Platform.environment['DARTDOC_ORIGINAL'] ?? 'main';
  print('using branch/tag: $branch for comparison from \$DARTDOC_ORIGINAL');
  return branch;
}

Future<void> runHelp(ArgResults commandResults) async {
  if (commandResults.rest.isEmpty) {
    // TODO(srawlins): Add more help for more individual commands.
    print('''
Usage:
    dart tool/task.dart [analyze|build|buildbot|clean|compare|doc|help|serve|test|tryp-publish|validate] options...

Help usage:
    dart tool/task.dart help [doc|serve]
''');
    return;
  }
  if (commandResults.rest.length != 1) {
    throw ArgumentError('"help" command requires a single command name.');
  }
  var command = commandResults.rest.single;
  return switch (command) {
    'build' => _buildHelp(),
    'doc' => _docHelp(),
    'serve' => _serveHelp(),
    _ => throw UnimplementedError(
        'Unknown command: "$command", or no specific help text'),
  };
}

Future<void> runServe(ArgResults commandResults) async {
  if (commandResults.rest.length != 1) {
    throw ArgumentError('"serve" command requires a single target.');
  }
  var target = commandResults.rest.single;
  await switch (target) {
    'flutter' => serveFlutterDocs(),
    'help' => _serveHelp(),
    'package' => _servePackageDocs(commandResults),
    'sdk' => serveSdkDocs(),
    'testing-package' => serveTestingPackageDocs(),
    _ => throw UnimplementedError('Unknown serve target: "$target"'),
  };
}

Future<void> serveFlutterDocs() async {
  await docFlutter();
  print('launching dhttpd on port 8001 for Flutter');
  var launcher = SubprocessLauncher('serve-flutter-docs');
  await launcher.runStreamedDartCommand(['pub', 'get']);
  await launcher.runStreamedDartCommand([
    'pub',
    'global',
    'run',
    'dhttpd',
    '--port',
    '8001',
    '--path',
    path.join(flutterDir.path, 'dev', 'docs', 'doc'),
  ]);
}

Future<void> _serveHelp() async {
  print('''
Usage:
dart tool/task.dart serve [flutter|package|sdk|testing-package]
$docUsage
''');
}

Future<void> _servePackageDocs(ArgResults commandResults) async {
  var name = commandResults['name'] as String;
  var version = commandResults['version'] as String?;
  await servePackageDocs(name: name, version: version);
}

Future<void> servePackageDocs(
    {required String name, required String? version}) async {
  var packageDocsPath = await docPackage(name: name, version: version);
  await _serveDocsFrom(packageDocsPath, 9000, 'serve-pub-package');
}

Future<void> serveSdkDocs() async {
  await docSdk();
  print('launching dhttpd on port 8000 for SDK');
  await SubprocessLauncher('serve-sdk-docs').runStreamedDartCommand([
    'pub',
    'global',
    'run',
    'dhttpd',
    '--port',
    '8000',
    '--path',
    _sdkDocsDir.path,
  ]);
}

bool _serveReady = false;

Future<void> _serveDocsFrom(String servePath, int port, String context) async {
  print('launching dhttpd on port $port for $context');
  var launcher = SubprocessLauncher(context);
  if (!_serveReady) {
    await launcher.runStreamedDartCommand(['pub', 'get']);
    await launcher
        .runStreamedDartCommand(['pub', 'global', 'activate', 'dhttpd']);
    _serveReady = true;
  }
  await launcher.runStreamedDartCommand([
    'pub',
    'global',
    'run',
    'dhttpd',
    '--port',
    '$port',
    '--path',
    servePath
  ]);
}

Future<void> serveTestingPackageDocs() async {
  var outputPath = await docTestingPackage();
  print('launching dhttpd on port 8002 for SDK');
  var launcher = SubprocessLauncher('serve-test-package-docs');
  await launcher.runStreamed(Platform.resolvedExecutable, [
    'pub',
    'global',
    'run',
    'dhttpd',
    '--port',
    '8002',
    '--path',
    outputPath,
  ]);
}

Future<void> runTest() async {
  await analyzeTestPackages();
  await SubprocessLauncher('dart test')
      .runStreamedDartCommand(['--enable-asserts', 'run', 'test']);
}

Future<void> runTryPublish() async {
  const arguments = ['pub', 'publish', '-n'];
  stderr.writeln(
    'try-publish: + ${Platform.resolvedExecutable} ${arguments.join(' ')}',
  );

  final result = await Process.run(
    Platform.resolvedExecutable,
    arguments,
    includeParentEnvironment: true,
  );

  if (result.stdout case final String stdoutText when stdoutText.isNotEmpty) {
    stdout.write(
      stdoutText.endsWith('\n') ? stdoutText : '$stdoutText\n',
    );
  }
  if (result.stderr case final String stderrText when stderrText.isNotEmpty) {
    stderr.write(
      stderrText.endsWith('\n') ? stderrText : '$stderrText\n',
    );
  }

  if (result.exitCode == 0) {
    return;
  }

  final combinedOutput =
      '${result.stdout is String ? result.stdout : ''}\n'
      '${result.stderr is String ? result.stderr : ''}';
  if (_isPublishDryRunWarningOnly(result.exitCode, combinedOutput)) {
    stderr.writeln(
      'try-publish: continuing after warning-only pub publish dry-run result.',
    );
    return;
  }

  throw SubprocessException(
    command: '${Platform.resolvedExecutable} ${arguments.join(' ')}',
    workingDirectory: null,
    exitCode: result.exitCode,
    environment: const {},
  );
}

bool _isPublishDryRunWarningOnly(int exitCode, String output) {
  if (exitCode != 65) return false;
  if (!output.contains('Package has ') || !output.contains('warning.')) {
    return false;
  }
  if (output.contains("can't be published yet")) {
    return false;
  }
  if (output.contains('missing a requirement')) {
    return false;
  }
  if (output.contains('found the following error')) {
    return false;
  }
  return true;
}

Future<void> runValidate(ArgResults commandResults) async {
  for (var target in commandResults.rest) {
    await switch (target) {
      'build' => validateBuild(),
      'dartdoc-docs' => validateDartdocDocs(),
      'format' => validateFormat(),
      'jaspr-launch' => validateJasprLaunch(),
      'package-release' => validatePackageRelease(),
      'jaspr-release' => validateJasprRelease(),
      'jaspr-route-smoke' => validateJasprRouteSmoke(),
      'jaspr-route-smoke-base-path' => validateJasprRouteSmokeBasePath(),
      'vitepress-smoke' => validateVitePressSmoke(),
      'jaspr-theme' => validateJasprTheme(),
      'jaspr-search-perf' => validateJasprSearchPerf(),
      'jaspr-theme-golden' => validateJasprThemeGolden(),
      'jaspr-theme-visual' => validateJasprThemeVisual(),
      'sdk-docs' => validateSdkDocs(),
      _ => throw UnimplementedError('Unknown validation target: "$target"'),
    };
  }
}

Future<void> validateJasprLaunch() async {
  await _validateJasprThemePrerequisites();

  final primaryWorkspace = await _prepareJasprPreviewWorkspace(
    labelPrefix: 'launch-theme',
    theme: 'forest',
  );
  final basePathWorkspace = await _prepareJasprPreviewWorkspace(
    labelPrefix: 'launch-theme-base-path',
    theme: 'forest',
    basePath: '/dartdoc-preview',
  );

  try {
    _assertJasprBuiltGuideExists(primaryWorkspace.outputDir.path);
    _assertJasprBuiltGuideExists(basePathWorkspace.outputDir.path);

    await validateJasprRouteSmoke(
      previewDir: primaryWorkspace.outputDir.path,
      theme: primaryWorkspace.theme,
      reuseBuild: true,
    );
    await validateJasprRouteSmokeBasePath(
      previewDir: basePathWorkspace.outputDir.path,
      theme: basePathWorkspace.theme,
      reuseBuild: true,
    );
    await validateJasprSearchPerf(
      previewDir: primaryWorkspace.outputDir.path,
      theme: primaryWorkspace.theme,
      reuseBuild: true,
    );
  } finally {
    primaryWorkspace.dispose();
    basePathWorkspace.dispose();
  }
}

Future<void> validateJasprRelease() async {
  await analyzePackage();
  await runTryPublish();
  await validateJasprLaunch();
}

Future<void> validatePackageRelease() async {
  await validateJasprRelease();
  await validateVitePressSmoke();
}

Future<void> validateVitePressSmoke() async {
  await SubprocessLauncher('vitepress-smoke').runStreamedDartCommand([
    'test',
    path.join('test', 'end2end', 'vitepress_generator_test.dart'),
  ]);
}

Future<void> validateJasprTheme() async {
  await _validateJasprThemePrerequisites();

  final workspace = await _prepareJasprPreviewWorkspace(
    labelPrefix: 'theme',
    theme: 'forest',
  );

  try {
    _assertJasprBuiltGuideExists(workspace.outputDir.path);
  } finally {
    workspace.dispose();
  }
}

Future<void> _validateJasprThemePrerequisites() async {
  await SubprocessLauncher('analyze-theme-e2e').runStreamedDartCommand([
    'analyze',
    path.join('test', 'end2end', 'jaspr_generator_test.dart'),
  ]);

  await SubprocessLauncher('theme-preview-script').runStreamed(
    'bash',
    ['-n', _bashPath(['tool', 'jaspr_theme_preview.sh'])],
  );
  await SubprocessLauncher('theme-snapshot-script').runStreamed(
    'bash',
    ['-n', _bashPath(['tool', 'jaspr_theme_snapshot.sh'])],
  );
  await SubprocessLauncher('search-profile-script').runStreamed(
    'bash',
    ['-n', _bashPath(['tool', 'jaspr_search_profile.sh'])],
  );
  await SubprocessLauncher('route-smoke-script').runStreamed(
    'bash',
    ['-n', _bashPath(['tool', 'jaspr_route_smoke.sh'])],
  );
}

Future<_JasprPreviewWorkspace> _prepareJasprPreviewWorkspace({
  required String labelPrefix,
  required String theme,
  String basePath = '',
}) async {
  final outputDir =
      Directory.systemTemp.createTempSync('dartdoc-jaspr-$labelPrefix');
  final pubCacheDir =
      Directory.systemTemp.createTempSync('dartdoc-jaspr-$labelPrefix-pub');

  try {
    _prepareOfflinePubCache(pubCacheDir);

    await SubprocessLauncher('generate-$labelPrefix').runStreamedDartCommand([
      'run',
      path.join(Directory.current.path, 'bin', 'dartdoc_vitepress.dart'),
      '--format',
      'jaspr',
      '--output',
      outputDir.path,
    ], workingDirectory: path.join('testing', 'test_package_with_docs'));

    await _runPubGetWithOfflineFallback(
      labelPrefix: labelPrefix,
      workingDirectory: outputDir.path,
      pubCachePath: pubCacheDir.path,
    );

    await SubprocessLauncher('$labelPrefix-analyze').runStreamedDartCommand([
      'analyze',
    ], workingDirectory: outputDir.path, environment: {
      'PUB_CACHE': pubCacheDir.path,
    });

    final homeDirPath = _resolveHomeDirPath();
    final jasprBinDir = path.join(homeDirPath, '.pub-cache', 'bin');
    await SubprocessLauncher('$labelPrefix-build').runStreamed(
      'jaspr',
      [
        'build',
        '--dart-define',
        'DOCS_THEME=$theme',
        '--dart-define',
        'DOCS_BASE_PATH=$basePath',
      ],
      workingDirectory: outputDir.path,
      environment: {
        'PUB_CACHE': pubCacheDir.path,
        'PATH': _prependPathEntry(jasprBinDir, Platform.environment['PATH']),
      },
    );

    return _JasprPreviewWorkspace(
      outputDir: outputDir,
      pubCacheDir: pubCacheDir,
      theme: theme,
      basePath: basePath,
    );
  } catch (_) {
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    if (pubCacheDir.existsSync()) {
      pubCacheDir.deleteSync(recursive: true);
    }
    rethrow;
  }
}

Future<void> _runPubGetWithOfflineFallback({
  required String labelPrefix,
  required String workingDirectory,
  required String pubCachePath,
}) async {
  final launcher = SubprocessLauncher('$labelPrefix-pub-get');
  final environment = {'PUB_CACHE': pubCachePath};

  try {
    await launcher.runStreamedDartCommand(
      ['pub', 'get', '--offline'],
      workingDirectory: workingDirectory,
      environment: environment,
    );
  } on SubprocessException {
    await launcher.runStreamedDartCommand(
      ['pub', 'get'],
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }
}

void _assertJasprBuiltGuideExists(String outputDirPath) {
  final builtGuide = File(path.joinAll([
    outputDirPath,
    'build',
    'jaspr',
    'guide',
    'getting-started',
    'index.html',
  ]));
  if (!builtGuide.existsSync()) {
    throw StateError(
      'Expected static Jaspr preview route at ${builtGuide.path}, but it was not generated.',
    );
  }
}

Future<void> validateJasprThemeVisual() async {
  final playwrightDir = _resolvePlaywrightDirPath();
  final outputDir =
      Directory.systemTemp.createTempSync('dartdoc-jaspr-theme-shots');

  try {
    await SubprocessLauncher('theme-snapshot-run').runStreamed(
      'bash',
      [_bashPath(['tool', 'jaspr_theme_snapshot.sh'])],
      environment: {
        'PLAYWRIGHT_DIR': playwrightDir,
        'OUTPUT_DIR': outputDir.path,
      },
    );

    for (final fileName in [
      'index.html',
      'manifest.json',
      for (final theme in ['ocean', 'graphite', 'forest'])
        ...[
          '$theme-desktop-light.png',
          '$theme-desktop-dark.png',
          '$theme-mobile-light.png',
          '$theme-mobile-dark.png',
        ],
    ]) {
      final file = File(path.join(outputDir.path, fileName));
      if (!file.existsSync()) {
        throw StateError(
          'Expected visual artifact at ${file.path}, but it was not generated.',
        );
      }
      if (file.lengthSync() == 0) {
        throw StateError(
          'Expected visual artifact at ${file.path} to be non-empty.',
        );
      }
    }

    final manifestFile = File(path.join(outputDir.path, 'manifest.json'));
    final manifestText = manifestFile.readAsStringSync();
    for (final needle in [
      '"theme": "ocean"',
      '"theme": "graphite"',
      '"theme": "forest"',
      '"viewport": "desktop"',
      '"viewport": "mobile"',
      '"mode": "light"',
      '"mode": "dark"',
    ]) {
      if (!manifestText.contains(needle)) {
        throw StateError(
          'Visual manifest did not include expected marker: $needle',
        );
      }
    }

    final reportFile = File(path.join(outputDir.path, 'index.html'));
    final reportText = reportFile.readAsStringSync();
    for (final needle in [
      'Jaspr Theme Snapshot Report',
      'desktop / light',
      'desktop / dark',
      'mobile / light',
      'mobile / dark',
    ]) {
      if (!reportText.contains(needle)) {
        throw StateError(
          'Visual snapshot report did not include expected marker: $needle',
        );
      }
    }
  } finally {
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
  }
}

Future<void> validateJasprThemeGolden() async {
  final playwrightDir = _resolvePlaywrightDirPath();
  await SubprocessLauncher('theme-golden-script').runStreamed(
    'bash',
    [_bashPath(['tool', 'jaspr_theme_golden.sh']), 'verify'],
    environment: {
      'PLAYWRIGHT_DIR': playwrightDir,
    },
  );
}

Future<void> validateJasprRouteSmoke({
  String? previewDir,
  String theme = 'ocean',
  bool reuseBuild = false,
}) async {
  final playwrightDir = _resolvePlaywrightDirPath();
  final outputDir =
      Directory.systemTemp.createTempSync('dartdoc-jaspr-route-smoke');

  try {
    final reportFile = path.join(outputDir.path, 'report.json');
    await SubprocessLauncher('route-smoke-run').runStreamed(
      'bash',
      [_bashPath(['tool', 'jaspr_route_smoke.sh'])],
      environment: {
        'PLAYWRIGHT_DIR': playwrightDir,
        'OUTPUT_DIR': outputDir.path,
        ...?previewDir == null ? null : {'PREVIEW_DIR': previewDir},
        'THEME': theme,
        'REUSE_BUILD': reuseBuild ? '1' : '0',
      },
    );

    final report = File(reportFile);
    if (!report.existsSync()) {
      throw StateError(
        'Expected Jaspr route smoke report at $reportFile, but it was not generated.',
      );
    }

    final payload =
        jsonDecode(report.readAsStringSync()) as Map<String, Object?>;
    final routes = payload['routes'] as Map<String, Object?>? ?? const {};
    final diagnostics =
        payload['diagnostics'] as Map<String, Object?>? ?? const {};
    final desktop = payload['desktop'] as Map<String, Object?>? ?? const {};
    final mobile = payload['mobile'] as Map<String, Object?>? ?? const {};

    for (final key in ['entryGuide', 'secondaryGuide', 'greeterApi']) {
      final value = routes[key] as String? ?? '';
      if (!value.startsWith('/')) {
        throw StateError(
          'Expected Jaspr route smoke report to contain a normalized route for $key, got "$value".',
        );
      }
    }

    final consoleErrors =
        (diagnostics['consoleErrors'] as List<Object?>? ?? const [])
            .cast<Object?>();
    final pageErrors =
        (diagnostics['pageErrors'] as List<Object?>? ?? const [])
            .cast<Object?>();
    final httpErrors =
        (diagnostics['httpErrors'] as List<Object?>? ?? const [])
            .cast<Object?>();
    final requestFailures =
        (diagnostics['requestFailures'] as List<Object?>? ?? const [])
            .cast<Object?>();

    if (consoleErrors.isNotEmpty ||
        pageErrors.isNotEmpty ||
        httpErrors.isNotEmpty ||
        requestFailures.isNotEmpty) {
      throw StateError(
        'Expected Jaspr route smoke diagnostics to be empty.\n'
        'consoleErrors: $consoleErrors\n'
        'pageErrors: $pageErrors\n'
        'httpErrors: $httpErrors\n'
        'requestFailures: $requestFailures',
      );
    }

    final desktopGuideHeading =
        (desktop['visitedGuideHeading'] as String? ?? '').toLowerCase();
    final desktopApiHeading =
        (desktop['visitedApiHeading'] as String? ?? '').toLowerCase();
    final mobileHeading = (mobile['heading'] as String? ?? '').toLowerCase();
    final breadcrumbCount = (desktop['breadcrumbCount'] as num?)?.toInt() ?? 0;

    if (!desktopGuideHeading.contains('configuration')) {
      throw StateError(
        'Expected desktop route smoke to reach the configuration guide, got "${desktop['visitedGuideHeading']}".',
      );
    }
    if (!desktopApiHeading.contains('greeter')) {
      throw StateError(
        'Expected desktop route smoke to reach a Greeter API page, got "${desktop['visitedApiHeading']}".',
      );
    }
    if (!mobileHeading.contains('configuration')) {
      throw StateError(
        'Expected mobile route smoke to reach the configuration guide, got "${mobile['heading']}".',
      );
    }
    if (breadcrumbCount <= 0) {
      throw StateError(
        'Expected desktop route smoke to confirm breadcrumbs on the API page.',
      );
    }
  } finally {
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
  }
}

Future<void> validateJasprRouteSmokeBasePath({
  String? previewDir,
  String theme = 'ocean',
  bool reuseBuild = false,
}) async {
  final playwrightDir = _resolvePlaywrightDirPath();
  final outputDir =
      Directory.systemTemp.createTempSync('dartdoc-jaspr-route-smoke-base');

  try {
    final reportFile = path.join(outputDir.path, 'report.json');
    const basePath = '/dartdoc-preview';
    await SubprocessLauncher('route-smoke-base-path-run').runStreamed(
      'bash',
      [path.join('tool', 'jaspr_route_smoke.sh')],
      environment: {
        'PLAYWRIGHT_DIR': playwrightDir,
        'OUTPUT_DIR': outputDir.path,
        'BASE_PATH': basePath,
        ...?previewDir == null ? null : {'PREVIEW_DIR': previewDir},
        'THEME': theme,
        'REUSE_BUILD': reuseBuild ? '1' : '0',
      },
    );

    final report = File(reportFile);
    if (!report.existsSync()) {
      throw StateError(
        'Expected Jaspr base-path route smoke report at $reportFile, but it was not generated.',
      );
    }

    final payload =
        jsonDecode(report.readAsStringSync()) as Map<String, Object?>;
    final reportedBasePath = payload['basePath'] as String? ?? '';
    if (reportedBasePath != basePath) {
      throw StateError(
        'Expected Jaspr base-path route smoke to report "$basePath", got "$reportedBasePath".',
      );
    }

    final routes = payload['routes'] as Map<String, Object?>? ?? const {};
    for (final key in ['entryGuide', 'secondaryGuide', 'greeterApi']) {
      final value = routes[key] as String? ?? '';
      if (!value.startsWith('/')) {
        throw StateError(
          'Expected Jaspr base-path route smoke report to contain a normalized route for $key, got "$value".',
        );
      }
      if (value.startsWith(basePath)) {
        throw StateError(
          'Expected Jaspr base-path route smoke to normalize $key without the base path, got "$value".',
        );
      }
    }
  } finally {
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
  }
}

Future<void> validateJasprSearchPerf({
  String? previewDir,
  String theme = 'ocean',
  bool reuseBuild = false,
}) async {
  final playwrightDir = _resolvePlaywrightDirPath();
  final outputDir =
      Directory.systemTemp.createTempSync('dartdoc-jaspr-search-profile');

  try {
    final reportFile = path.join(outputDir.path, 'report.json');
    await SubprocessLauncher('search-profile-run').runStreamed(
      'bash',
      [path.join('tool', 'jaspr_search_profile.sh')],
      environment: {
        'PLAYWRIGHT_DIR': playwrightDir,
        'OUTPUT_DIR': outputDir.path,
        ...?previewDir == null ? null : {'PREVIEW_DIR': previewDir},
        'THEME': theme,
        'REUSE_BUILD': reuseBuild ? '1' : '0',
      },
    );

    final report = File(reportFile);
    if (!report.existsSync()) {
      throw StateError(
        'Expected Jaspr search profile report at $reportFile, but it was not generated.',
      );
    }

    final payload =
        jsonDecode(report.readAsStringSync()) as Map<String, Object?>;
    final scenarios = (payload['scenarios'] as List<Object?>? ?? const [])
        .cast<Map<String, Object?>>();
    if (scenarios.length < 2) {
      throw StateError('Expected desktop and mobile search perf scenarios.');
    }

    for (final scenario in scenarios) {
      final scenarioId = scenario['id'] as String? ?? 'unknown';
      final firstOpenMs = (scenario['firstOpenMs'] as num?)?.toDouble() ?? 0;
      final warmOpenMs = (scenario['warmOpenMs'] as num?)?.toDouble() ?? 0;
      final firstOpenRequests =
          (scenario['firstOpenRequests'] as List<Object?>? ?? const [])
              .cast<String>();
      final warmOpenRequests =
          (scenario['warmOpenRequests'] as List<Object?>? ?? const [])
              .cast<String>();
      final deepQuery = scenario['deepQuery'] as Map<String, Object?>? ?? const {};
      final unicodeQuery =
          scenario['unicodeQuery'] as Map<String, Object?>? ?? const {};

      if (!firstOpenRequests.any(
        (entry) => entry.endsWith('/search_index.json'),
      )) {
        throw StateError(
          'Expected cold search open to load the search manifest for $scenarioId.',
        );
      }
      if (!firstOpenRequests.any(
        (entry) => entry.endsWith('/search_pages.json'),
      )) {
        throw StateError(
          'Expected cold search open to load page entries for $scenarioId.',
        );
      }
      if (warmOpenRequests.any((entry) => entry.endsWith('/search_pages.json'))) {
        throw StateError(
          'Warm search open unexpectedly refetched page entries for $scenarioId.',
        );
      }
      if (warmOpenRequests.any((entry) => entry.endsWith('/search_sections.json'))) {
        throw StateError(
          'Warm search open unexpectedly refetched section metadata for $scenarioId.',
        );
      }
      if (warmOpenRequests.any((entry) => entry.endsWith('/search_index.json'))) {
        throw StateError(
          'Warm search open unexpectedly refetched the manifest for $scenarioId.',
        );
      }

      final deepResultCount =
          (deepQuery['resultCount'] as num?)?.toInt() ?? 0;
      final deepRequests = (deepQuery['requests'] as List<Object?>? ?? const [])
          .cast<String>();
      if (deepResultCount < 0) {
        throw StateError('Deep query result count was invalid for $scenarioId.');
      }
      if (!deepRequests.any((entry) => entry.endsWith('/search_sections.json'))) {
        throw StateError(
          'Expected deep query to load section metadata for $scenarioId.',
        );
      }
      if (!deepRequests.any(
        (entry) => entry.endsWith('/search_sections_content.json'),
      )) {
        throw StateError(
          'Expected deep query to trigger deferred section content for $scenarioId.',
        );
      }

      final unicodeResultCount =
          (unicodeQuery['resultCount'] as num?)?.toInt() ?? 0;
      if (unicodeResultCount <= 0) {
        throw StateError(
          'Expected Unicode query to resolve to the seeded fixture for $scenarioId.',
        );
      }

      final firstOpenBudget = scenarioId == 'mobile' ? 3200 : 1600;
      final warmOpenBudget = scenarioId == 'mobile' ? 1800 : 900;
      if (firstOpenMs > firstOpenBudget) {
        throw StateError(
          'Cold search open exceeded the budget for $scenarioId: ${firstOpenMs.toStringAsFixed(1)}ms > ${firstOpenBudget}ms.',
        );
      }
      if (warmOpenMs > warmOpenBudget) {
        throw StateError(
          'Warm search open exceeded the budget for $scenarioId: ${warmOpenMs.toStringAsFixed(1)}ms > ${warmOpenBudget}ms.',
        );
      }
    }
  } finally {
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
  }
}

void _prepareOfflinePubCache(Directory pubCacheDir) {
  final homeDirPath = _resolveHomeDirPath();

  void linkIfPresent(String name) {
    final target = Directory(path.join(homeDirPath, '.pub-cache', name));
    final linkPath = path.join(pubCacheDir.path, name);
    if (target.existsSync() && !Link(linkPath).existsSync()) {
      Link(linkPath).createSync(target.path);
    }
  }

  linkIfPresent('hosted');
  linkIfPresent('git');
  linkIfPresent('hosted-hashes');
}

String _resolveHomeDirPath() {
  final homeDirPath = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'];
  if (homeDirPath == null || homeDirPath.isEmpty) {
    throw StateError('Unable to determine the user home directory.');
  }
  return homeDirPath;
}

String _resolvePlaywrightDirPath() {
  final candidates = [
    Platform.environment['PLAYWRIGHT_DIR'],
    '/tmp/pw-run',
  ].whereType<String>().where((value) => value.isNotEmpty);

  for (final playwrightDir in candidates) {
    final playwrightPackageDir = Directory(
      path.join(playwrightDir, 'node_modules', 'playwright'),
    );
    if (playwrightPackageDir.existsSync()) {
      return playwrightDir;
    }
  }

  throw StateError(
    'Playwright was not found. Set PLAYWRIGHT_DIR or install it into /tmp/pw-run.',
  );
}

Future<void> validateBuild() async {
  var originalFileContents = <String, String>{};
  var differentFiles = <String>[];

  // Load original file contents into memory before running the builder; it
  // modifies them in place.
  for (var relPath in _generatedFilesList) {
    var origPath = path.joinAll(['lib', relPath]);
    var oldVersion = File(origPath);
    if (oldVersion.existsSync()) {
      originalFileContents[relPath] = oldVersion.readAsStringSync();
    }
  }

  await buildAll();

  for (var relPath in _generatedFilesList) {
    var newVersion = File(path.join('lib', relPath));
    if (!newVersion.existsSync()) {
      print('${newVersion.path} does not exist\n');
      differentFiles.add(relPath);
    } else {
      var newVersionText = await newVersion.readAsString();
      if (originalFileContents[relPath] != newVersionText) {
        print('${newVersion.path} has changed to: \n$newVersionText)');
        differentFiles.add(relPath);
      }
    }
  }

  if (differentFiles.isNotEmpty) {
    throw StateError('''
The following generated files needed to be rebuilt:
  ${differentFiles.map((f) => path.join('lib', f)).join("\n  ")}
Rebuild them with "dart tool/task.dart build" and check the results in.
''');
  }

  // Verify that the web frontend has been compiled.
  final currentSig =
      await _calcFilesSig(Directory('web'), extensions: {'.dart', '.scss'});
  final lastCompileSig =
      File(path.join('web', 'sig.txt')).readAsStringSync().trim();
  if (currentSig != lastCompileSig) {
    print('current files: $currentSig');
    print('cached sig   : $lastCompileSig');
    throw StateError(
        'The web frontend (web/docs.dart) needs to be recompiled; rebuild it '
        'with "dart tool/task.dart build web".');
  }

  // Reset some files for `try-publish` step. This check looks for changes in
  // the current git checkout: https://github.com/dart-lang/pub/pull/4373.
  Process.runSync('git', [
    'checkout',
    '--',
    'lib/resources/docs.dart.js',
    'lib/resources/docs.dart.js.map',
  ]);
}

/// Paths in this list are relative to lib/.
final _generatedFilesList = [
  '../dartdoc_options.yaml',
  'src/generator/html_resources.g.dart',
  'src/generator/templates.aot_renderers_for_html.dart',
  'src/version.dart',
  '../test/mustachio/foo.dart',
].map((s) => path.joinAll(path.posix.split(s)));

Future<void> validateDartdocDocs() async {
  var launcher = SubprocessLauncher('test-dartdoc');
  await launcher.runStreamedDartCommand([
    '--enable-asserts',
    path.join('bin', 'dartdoc_vitepress.dart'),
    '--output',
    _dartdocDocsPath,
    '--no-link-to-remote',
  ]);
  _expectFileContains(path.join(_dartdocDocsPath, 'index.html'),
      '<title>dartdoc_vitepress - Dart API docs</title>');
  var objectText = RegExp('<li>Object</li>', multiLine: true);
  _expectFileContains(
    path.join(_dartdocDocsPath, 'dartdoc', 'PubPackageMeta-class.html'),
    objectText,
  );
}

/// Kind of an inefficient grepper for now.
void _expectFileContains(String filePath, Pattern text) {
  var source = File(filePath);
  if (!source.existsSync()) {
    throw StateError('file not found: $filePath');
  }
  if (!File(filePath).readAsStringSync().contains(text)) {
    throw StateError('"$text" not found in $filePath');
  }
}

final String _dartdocDocsPath =
    Directory.systemTemp.createTempSync('dartdoc').path;

Future<void> validateFormat() async {
  var processResult = Process.runSync(Platform.resolvedExecutable, [
    'format',
    '-o',
    'none',
    'bin',
    'lib',
    'test',
    'tool',
    'web',
  ]);
  if (processResult.exitCode != 0) {
    throw StateError('''
Not all files are formatted:

    ${processResult.stderr}
''');
  }
}

Future<void> validateSdkDocs() async {
  await docSdk();
  const expectedLibCount = 0;
  const expectedSubLibCount = 20;
  const expectedTotalCount = 20;
  var indexHtml = File(path.join(_sdkDocsDir.path, 'index.html'));
  if (!indexHtml.existsSync()) {
    throw StateError("No 'index.html' found for the SDK docs");
  }
  print("Found 'index.html'");
  var indexContents = indexHtml.readAsStringSync();
  var foundLibCount = _findCount(indexContents, '  <li><a href="dart-');
  if (expectedLibCount != foundLibCount) {
    throw StateError(
        "Expected $expectedLibCount 'dart:' entries in 'index.html', but "
        'found $foundLibCount');
  }
  print("Found $foundLibCount 'dart:' entries in 'index.html'");

  var libLinkPattern =
      RegExp('<li class="section-subitem"><a [^>]*href="dart-');
  var foundSubLibCount = _findCount(indexContents, libLinkPattern);
  if (expectedSubLibCount != foundSubLibCount) {
    throw StateError("Expected $expectedSubLibCount 'dart:' entries in "
        "'index.html' to be in categories, but found $foundSubLibCount");
  }
  print('$foundSubLibCount index.html dart: entries in categories found');

  // Check for the existence of certain files and directories.
  var libraries =
      _sdkDocsDir.listSync().where((fs) => fs.path.contains('dart-'));
  var libraryCount = libraries.length;
  if (expectedTotalCount != libraryCount) {
    var libraryNames =
        libraries.map((l) => "'${path.basename(l.path)}'").join(', ');
    throw StateError('Unexpected docs generated for SDK libraries; expected '
        '$expectedTotalCount directories, but $libraryCount directories were '
        'generated: $libraryNames');
  }
  print("Found $libraryCount 'dart:' libraries");

  var futureConstructorFile =
      File(path.join(_sdkDocsDir.path, 'dart-async', 'Future', 'Future.html'));
  if (!futureConstructorFile.existsSync()) {
    throw StateError('No Future.html found for dart:async Future constructor');
  }
  print('Found Future.async constructor');
}

/// A temporary directory into which the SDK can be documented.
final Directory _sdkDocsDir =
    Directory.systemTemp.createTempSync('sdkdocs').absolute;

/// Returns the number of (perhaps overlapping) occurrences of [str] in [match].
int _findCount(String str, Pattern match) {
  var count = 0;
  var index = str.indexOf(match);
  while (index != -1) {
    count++;
    index = str.indexOf(match, index + 1);
  }
  return count;
}

Future<String> _calcFilesSig(Directory dir,
    {required Set<String> extensions}) async {
  final digest = await _fileLines(dir, extensions: extensions)
      .transform(utf8.encoder)
      .transform(crypto.md5)
      .single;

  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
}

/// Returns a map of warning texts to the number of times each has been seen.
WarningsCollection _collectWarnings({
  required Iterable<Map<Object, Object?>> messages,
  required String tempPath,
  required String branch,
  String? pubDir,
}) {
  var warningTexts = WarningsCollection(tempPath, pubDir, branch);
  for (final message in messages) {
    if (message.containsKey('level') &&
        message['level'] == 'WARNING' &&
        message.containsKey('data')) {
      var data = message['data'] as Map;
      warningTexts.add(data['text'] as String);
    }
  }
  return warningTexts;
}
