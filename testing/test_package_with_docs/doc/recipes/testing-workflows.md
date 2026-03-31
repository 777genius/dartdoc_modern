# Testing Workflows

Use this guide to compare recipe-style content between Jaspr and VitePress.

## Smoke Tests

Use `GreetingScenario.smoke` when you only want to verify that a rendered greeting appears.

## Integration Recipes

Use `RecordingGreeter` when you need to assert which recipient was targeted.

### Recorder Pattern

```dart
final greeter = RecordingGreeter();
greeter.greet('Taylor');
print(greeter.lastRecipient);
```

:::danger Testing Trap
Do not use global mutable state in examples unless you want the docs to demonstrate cleanup patterns too.
:::
