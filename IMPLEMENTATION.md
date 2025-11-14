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

## Backend Table Format Customization & Theme System

### Motivation

ModelSummaries renders tables through PrettyTables.jl 3.0 and needed a flexible theme system that:
- Allows users to supply their own table formats per backend
- Provides beautiful preset themes out-of-the-box
- Maintains backend-specific format choices attached to a `ModelSummary`
- Adapts to PrettyTables 3.x's new API (backend-specific format types instead of unified `TableFormat`)

### Design

1. **Persistent theme map**: `ModelSummary` holds a `table_format::Dict{Symbol, Any}` that stores the chosen format per
   backend (`:text`, `:html`, `:latex`). In PrettyTables 3.x, each backend has its own format type:
   - `LatexTableFormat` for LaTeX
   - `MarkdownTableFormat` for Markdown/Text
   - `HtmlTableFormat` for HTML
   - `TextTableFormat` for Text (unused; we use Markdown internally)

2. **Theme presets**: New `Themes` module provides 6 curated themes:
   - `:academic` - Professional booktabs style for publications
   - `:modern` - Clean markdown formatting
   - `:minimal` - Minimal decorations
   - `:compact` - Space-efficient layout
   - `:unicode` - Unicode box-drawing characters
   - `:default` - Alias for `:academic`

3. **Public keywords**:
   - `modelsummary(...; theme=:academic)` - Use a preset theme
   - `modelsummary(...; table_format=...)` - Fine-grained control with format objects or Dict
   - `theme` takes precedence over `table_format` if both are provided

4. **Normalization helper**: `_normalize_table_format` coerces user input into a complete Dict by:
   - Accepting PrettyTables format objects directly (e.g., `LatexTableFormat()`)
   - Resolving alias symbols (`:booktabs`, `:matrix`)
   - Expanding `NamedTuple`s or `Dict`s keyed by backend symbols
   - Falling back to defaults (MarkdownTableFormat, HtmlTableFormat, latex_table_format__booktabs)

5. **Rendering hook**: `_render_table` uses `table_format` keyword (not `tf`) to pass formats to PrettyTables.
   The function:
   - Pulls the backend-specific format from `rt.table_format`
   - Converts `:text` backend to `:markdown` internally (they both use MarkdownTableFormat)
   - Supports `body_hlines` only for LaTeX (PrettyTables 3.x limitation)

### PrettyTables 3.x Compatibility

**Breaking changes handled:**
- No unified `TableFormat` type → Use backend-specific types
- `tf` keyword removed → Use `table_format`
- No `tf_*` constants → Use constructors and specific constants like `latex_table_format__booktabs`
- `body_hlines` only works with LaTeX backend
- Markdown/HTML backends have limited customization options

### Benefits

- Beautiful preset themes that work out-of-the-box
- Easy discovery through `Themes.list_themes()`
- Users can configure themes once when constructing the table
- Backend-specific styling is symmetric with backend selection
- Fully backwards compatible with existing code
- Advanced users can still override via `merge_kwargs!` or direct `pretty_kwargs` access
- Extensible: users can create custom themes as Dict/NamedTuple

### Implementation Notes

**File: `src/themes.jl`**
- Defines theme constants (ACADEMIC, MODERN, etc.)
- Each theme is a `Dict{Symbol, Any}` mapping backends to format objects
- `get_theme()` resolves theme names or passes through custom dicts
- `list_themes()` provides user-friendly theme discovery

**File: `src/modelsummary_type.jl`**
- `default_table_format(backend)` returns appropriate format constructor
- `_normalize_table_format()` handles all input types
- `_coerce_table_format_value()` validates and converts format specifications
- `_render_table()` applies the format when calling PrettyTables

**File: `src/modelsummary.jl`**
- Added `theme` keyword parameter
- Theme processing happens before table_format normalization
- Warning if both theme and table_format are provided
