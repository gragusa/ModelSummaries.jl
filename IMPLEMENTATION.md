# Custom Covariance Specifications in ModelSummaries.jl

## Problem Statement

ModelSummaries.jl (formerly RegressionTables.jl) traditionally relied on whatever variance–covariance matrix a regression model exposed through
`StatsAPI.vcov(model)` (or the derived `stderror`). Users frequently need to display alternative standard errors—for
example heteroskedasticity‑robust estimators or clustered covariances produced by CovarianceMatrices.jl. Because the
package only accepted bare `RegressionModel`s, there was no ergonomic way to inject a custom variance estimator without
mutating the model itself. The goal is to let users choose the covariance estimator per model/per column while keeping
the existing API backwards compatible and allowing third‑party packages to plug in without tight coupling.

## Solution Overview

1. **Covariance specification objects**: Introduce `AbstractVcovSpec` along with concrete helpers for matrices and
   callables. A helper function `ModelSummaries.vcov(spec)` turns matrices, functions, or custom estimator objects into
   `AbstractVcovSpec`s.
2. **Model wrapper**: Define `RegressionModelWithVcov` that wraps any `RegressionModel` plus a spec. Users create these
   by writing `model + vcov(spec)`. The wrapper still subtypes `RegressionModel`, so it flows through the rest of the
   package unchanged.
3. **Extension point**: Provide `ModelSummaries.materialize_vcov(spec, model)` for external packages (e.g.
   CovarianceMatrices.jl) to return the actual matrix on demand. Matrices and functions already have default methods.
4. **Caching and delegation**: `_custom_vcov` caches the realized matrix inside the wrapper to avoid recomputation.
   Standard errors, `vcov`, and dependent quantities pull from this cache; everything else delegates to the original
   model.
5. **Documentation and tests**: README/docs now explain the API, and tests cover matrices, callables, overriding specs,
   and failure paths.

## Implementation Notes

- **File layout**: All logic lives in `src/regressionResults.jl`, alongside other helpers that adapt `RegressionModel`s.
- **Imports/exports**: `StatsAPI.vcov` is imported so the wrapper can override it. The package now exports `vcov` so users
  call `ModelSummaries.vcov`.
- **Wrapper behavior**:
  - `RegressionModelWithVcov` stores the original model, the spec, and a `Ref` cache.
  - `_custom_vcov` materializes the matrix via `materialize_vcov` and checks its dimensions against the coefficient
    vector.
  - `_custom_stderror` returns the square roots of diagonal entries; `_stderror` dispatches to it when the wrapper is
    present.
  - Delegation methods forward all other `StatsAPI` queries (coef, dof, nobs, etc.) to the wrapped model so existing
    statistics keep working.
- **User API**:
  - `model + vcov(matrix)` uses a provided matrix verbatim.
  - `model + vcov(model -> matrix)` or `model + vcov(() -> matrix)` compute the matrix lazily.
  - Any other object can participate if `ModelSummaries.materialize_vcov(obj, model)` is defined, giving external
    packages a clean hook.
- **Error handling**: Dimension mismatches, non-matrix returns, or unknown specs throw informative `ArgumentError`s so
  misconfigurations surface quickly.
- **Testing**: Added to `test/RegressionTables.jl` to assert correctness and caching semantics without depending on
  CovarianceMatrices.jl.

This architecture keeps the core API simple for end users, isolates the customization surface for partner packages, and
maintains backward compatibility with existing regression types.

## Backend Table Format Customization

### Motivation

ModelSummaries renders tables through PrettyTables.jl and historically hard-coded the Markdown/HTML/LaTeX themes.
Users requested the ability to supply their own `TableFormat` objects (for example, PrettyTables' Unicode rounded box or
custom corporate LaTeX styles) and to keep those preferences attached to a `ModelSummary` so every later `show`/`write`
call uses the same formatting without reapplying configuration.

### Design

1. **Persistent theme map**: `ModelSummary` now holds a `table_format::Dict{Symbol, PrettyTables.TableFormat}` that
   records the chosen theme per backend (`:text`, `:html`, `:latex`). The struct constructor normalizes user input so
   downstream code can rely on a canonical dictionary.
2. **Public keyword**: `modelsummary(...; table_format=...)` accepts a single format, alias symbol, `Dict`, or
   `NamedTuple`. Missing backends default to the stock PrettyTables themes (`tf_markdown`, `tf_html_minimalist`,
   `tf_latex_booktabs`). Passing `nothing` keeps the previous behavior.
3. **Normalization helper**: `_normalize_table_format` coerces user input into a complete Dict by:
   - Detecting alias symbols and mapping them to PrettyTables `tf_*` constants (both bare names like `:unicode_rounded`
     and explicit `:tf_unicode_rounded` are supported).
   - Expanding `NamedTuple`s or `Dict`s keyed by backend symbols.
   - Falling back to defaults when a backend is unspecified or explicitly set to `nothing`/`:default`.
4. **Rendering hook**: `_render_table` checks `rt.pretty_kwargs` for a user-specified `:tf`; if absent it pulls the
   backend-specific entry from `rt.table_format`. This preserves caller overrides set via `merge_kwargs!` while ensuring
   the new keyword drives the PrettyTables theme everywhere else.

### Benefits

- Users can configure themes once when constructing the table instead of mutating PrettyTables kwargs after the fact.
- Backend-specific styling is now symmetrical with backend selection, improving clarity of the public API.
- The implementation is backwards compatible: existing code that relied on PrettyTables defaults continues to work, and
  advanced users can still override `:tf` manually inside `pretty_kwargs` when needed.
