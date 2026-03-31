# Pipeline Patterns

This guide gives the docs site a second recipe page with search-heavy vocabulary.

## Prefix Then Uppercase

The simplest composition is `PrefixStage` followed by `UppercaseStage`.

<<< ../snippets/pipeline_showcase.dart#L1-L18

## Retry Strategy

`RetryPolicy` is intentionally small, but it creates meaningful API prose in generated docs.

### Operational Notes

- keep stage names readable
- prefer deterministic transforms in examples
- mention concrete types like `Pipeline<String>`
