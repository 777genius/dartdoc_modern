---
title: Architecture
description: Understand the package structure used by the docs showcase.
outlineCollapsible: true
---

# Architecture

This guide explains how the showcase package is intentionally structured to stress the docs generator.

## Public Libraries

- `test_package_with_docs.dart` provides `Greeter`, `GreetingResult`, and message formatting.
- `pipeline.dart` provides `Pipeline`, `Stage`, and `RetryPolicy`.
- `showcase_ui.dart` provides `ShowcasePageSpec`, `CardSection`, and `BadgeVariant`.
- `testing_support.dart` provides `RecordingGreeter` and `GreetingScenario`.

### Why Multiple Libraries

Using several public libraries gives us:

- a larger API sidebar
- more search coverage
- better breadcrumb validation
- better parity checks between Jaspr and VitePress

## Guide Structure

We keep guides in nested directories so the generated guide sidebar is not trivial.

### Sections

The structure intentionally includes:

- `advanced/`
- `recipes/`
- deep headings within each page

## Runtime Features

The showcase docs use:

- Mermaid diagrams
- DartPad embeds
- imported snippets
- inline API links

:::info Architectural Note
This fixture is meant to be pleasant to browse, not just technically broad.
:::
