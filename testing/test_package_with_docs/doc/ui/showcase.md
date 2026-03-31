# UI Showcase

This guide exists to compare visual docs output between backends.

## Page Specs

Use `ShowcasePageSpec` when you need a stable container for docs-driven UI examples.

## Sections

Each `CardSection` can carry a `BadgeVariant` and short supporting description.

### Suggested Composition

```dart
const page = ShowcasePageSpec(
  name: 'Overview',
  sections: [
    CardSection(
      title: 'Quick start',
      description: 'Get productive with the package fast.',
      badge: BadgeVariant.success,
    ),
  ],
);
```

## Why This Fixture Is Larger

Because a one-page docs fixture hides layout, search, sidebar, and outline problems.
