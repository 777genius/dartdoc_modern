/// Test-only helpers that still deserve polished docs output.
library testing_support;

import 'test_package_with_docs.dart';

/// Scenarios used by the guide recipes.
enum GreetingScenario {
  /// Fast sanity-check flow.
  smoke,

  /// Full integration-style flow.
  integration,

  /// Snapshot-oriented flow for docs comparisons.
  golden,
}

/// A fake greeter that records the latest recipient.
class RecordingGreeter extends Greeter {
  /// Creates a fake greeter with a stable template.
  RecordingGreeter() : super('Hi, {name}.');

  /// Last recorded recipient.
  String? lastRecipient;

  @override
  String greet(String name) {
    lastRecipient = name;
    return super.greet(name);
  }
}
