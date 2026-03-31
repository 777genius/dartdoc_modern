import 'package:test_package_with_docs/pipeline.dart';

String buildPipelineDemo() {
  final pipeline = Pipeline<String>(
    stages: const [
      PrefixStage('status: '),
      UppercaseStage(),
    ],
  );

  return pipeline.execute('ready');
}

void main() {
  print(buildPipelineDemo());
}
