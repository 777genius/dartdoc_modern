/// A showcase library with documentation guides, API surface, and examples.
library;

/// The default greeting template used throughout the showcase guides.
const defaultGreetingTemplate = 'Hello, {name}!';

/// Supported delivery channels for a rendered greeting.
enum DeliveryChannel {
  /// Write the greeting to the console or log sink.
  console,

  /// Return the greeting to the caller for further composition.
  memory,

  /// Pretend the greeting will be shown in a UI surface.
  overlay,
}

/// A lightweight strategy for formatting a [Greeter] output.
abstract class MessageFormatter {
  /// Formats a ready-to-send [message] for a given [channel].
  String format(String message, DeliveryChannel channel);
}

/// A simple formatter that prefixes the delivery channel.
class PrefixFormatter implements MessageFormatter {
  /// Creates a formatter with a custom [prefix].
  const PrefixFormatter(this.prefix);

  /// The static prefix inserted before the message.
  final String prefix;

  @override
  String format(String message, DeliveryChannel channel) {
    return '[$prefix:${channel.name}] $message';
  }
}

/// A result object used in docs to demonstrate structured API responses.
class GreetingResult {
  /// Creates a result containing the rendered [message].
  const GreetingResult({
    required this.message,
    required this.channel,
    required this.recipient,
  });

  /// The rendered greeting.
  final String message;

  /// Where the greeting is intended to be delivered.
  final DeliveryChannel channel;

  /// The target recipient.
  final String recipient;

  /// Whether the result looks safe to display in demos.
  bool get isPresentable => message.isNotEmpty && recipient.isNotEmpty;
}

/// A well-documented class for testing docs generation and linking.
class Greeter {
  /// Creates a new [Greeter] with the given [template].
  Greeter(
    this.template, {
    MessageFormatter? formatter,
  }) : formatter = formatter ?? const PrefixFormatter('showcase');

  /// The greeting template.
  final String template;

  /// The formatter used to shape the final greeting.
  final MessageFormatter formatter;

  /// Returns a greeting for the given [name].
  String greet(String name) => template.replaceAll('{name}', name);

  /// Renders a full [GreetingResult] for a [name] and [channel].
  GreetingResult deliver(
    String name, {
    DeliveryChannel channel = DeliveryChannel.console,
  }) {
    final message = formatter.format(greet(name), channel);
    return GreetingResult(
      message: message,
      channel: channel,
      recipient: name,
    );
  }
}

/// Creates a greeter using the [defaultGreetingTemplate].
Greeter createDefaultGreeter() => Greeter(defaultGreetingTemplate);

/// Adds a tiny helper API that should appear in docs and search.
extension GreeterInspection on Greeter {
  /// Returns a normalized label used in guides and demos.
  String get displayLabel => 'Greeter<${template.length}>';
}
