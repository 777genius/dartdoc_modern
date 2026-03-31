---
title: Configuration
description: Configure templates, pipelines, and showcase UI behavior.
outlineCollapsible: true
---

# Configuration

Advanced configuration guide.

## Options

Configure the greeter template, search-friendly content, and UI-oriented examples.

### Greeter Templates

Prefer readable placeholders like `{name}` so examples stay legible in generated markdown.

:::details Configuration Notes
- Inline references like `Greeter`, `Pipeline`, and `ShowcasePageSpec` should link to the API docs.
- Imported snippets should stay readable in generated markdown.
- Search should index both page-level and section-level content.
:::

### Pipeline Behavior

The `RetryPolicy` object exists to exercise configuration docs with nested headings and related API links.

#### Backoff Defaults

Small but concrete defaults make the generated docs feel more like a real package and less like a synthetic fixture.

:::warning Caveat
Do not hardcode user names inside the greeting template.
:::

## Visual Configuration

The `BadgeVariant` and `CardSection` APIs model a docs-friendly UI surface.

:::tip Recommended Setup
Use a restrained set of variants in examples so the docs remain easy to scan.
:::

## Testing Configuration

`RecordingGreeter` and `GreetingScenario` exist so recipes can reference testing-oriented APIs without inventing unsupported syntax.
