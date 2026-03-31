/// Pipeline-oriented helpers used by the docs showcase.
library pipeline;

/// A single transformation stage.
abstract class Stage<T> {
  /// Applies the stage to [input].
  T run(T input);
}

/// A retry configuration used in guides and examples.
class RetryPolicy {
  /// Creates a retry policy.
  const RetryPolicy({
    this.maxAttempts = 3,
    this.backoffFactor = 1.6,
  });

  /// Maximum number of attempts.
  final int maxAttempts;

  /// Exponential backoff multiplier.
  final double backoffFactor;
}

/// A serial pipeline that applies [Stage] instances one by one.
class Pipeline<T> {
  /// Creates a pipeline from [stages].
  Pipeline({
    required Iterable<Stage<T>> stages,
    this.retryPolicy = const RetryPolicy(),
  }) : stages = List.unmodifiable(stages);

  /// Ordered transformation stages.
  final List<Stage<T>> stages;

  /// Retry behavior used by the host application.
  final RetryPolicy retryPolicy;

  /// Runs all [stages] against [value].
  T execute(T value) {
    var current = value;
    for (final stage in stages) {
      current = stage.run(current);
    }
    return current;
  }
}

/// Wraps text in a prefix for docs examples.
class PrefixStage implements Stage<String> {
  /// Creates a prefixing stage.
  const PrefixStage(this.prefix);

  /// Prefix inserted before the input.
  final String prefix;

  @override
  String run(String input) => '$prefix$input';
}

/// Converts the input to uppercase.
class UppercaseStage implements Stage<String> {
  /// Creates an uppercase stage.
  const UppercaseStage();

  @override
  String run(String input) => input.toUpperCase();
}
