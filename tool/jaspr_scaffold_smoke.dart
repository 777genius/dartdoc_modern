import 'dart:io';

import 'src/jaspr_scaffold_smoke.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/jaspr_scaffold_smoke.dart <generated-jaspr-output-dir>',
    );
    exitCode = 64;
    return;
  }

  try {
    JasprScaffoldSmokeChecker(Directory(args.single)).run();
  } on Object catch (error) {
    stderr.writeln('Jaspr scaffold smoke check failed: $error');
    exitCode = 1;
    return;
  }

  stdout.writeln('Jaspr scaffold smoke check passed.');
}
