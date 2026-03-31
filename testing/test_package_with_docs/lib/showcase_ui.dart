/// UI-facing models used by the docs showcase.
library showcase_ui;

/// Small visual variants that should appear in generated docs.
enum BadgeVariant {
  /// Neutral label.
  subtle,

  /// Positive state.
  success,

  /// Warning state.
  warning,
}

/// Describes a card-like section in a docs showcase.
class CardSection {
  /// Creates a card section.
  const CardSection({
    required this.title,
    required this.description,
    this.badge = BadgeVariant.subtle,
  });

  /// Headline shown to the user.
  final String title;

  /// Supporting description.
  final String description;

  /// Visual emphasis.
  final BadgeVariant badge;
}

/// A simple immutable page spec.
class ShowcasePageSpec {
  /// Creates a page spec from [sections].
  const ShowcasePageSpec({
    required this.name,
    required this.sections,
  });

  /// Page name.
  final String name;

  /// Sections rendered on the page.
  final List<CardSection> sections;

  /// Returns the number of sections.
  int get sectionCount => sections.length;
}
