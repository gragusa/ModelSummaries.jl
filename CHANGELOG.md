# ModelSummaries.jl Changelog

# ModelSummaries.jl Changelog

## Unreleased

### Added
- New `table_format` keyword and `ModelSummary.table_format` field to control the PrettyTables `TableFormat` used by each backend. Users can now provide a single format, a backend-keyed `Dict`/`NamedTuple`, or alias symbols (e.g. `:unicode_rounded`) and the renderer will honor the selection for `:text`, `:html`, and `:latex` outputs.

## Version 0.1.0 - Complete Package Refactor

### Major Breaking Changes

#### 1. Package Rename
- **Old**: `RegressionTables2.jl`
- **New**: `ModelSummaries.jl`
- **UUID**: Changed from `ee7cb3fd-1e53-430d-af66-71c292f3fa61` to `69480e08-b3d8-4e45-a1a7-f96c93f12f9d`

#### 2. Type Rename
- **Old**: `RegressionTable`
- **New**: `ModelSummary`

#### 3. API Simplification - Backend Parameter

**Old API** (removed):
```julia
using RegressionTables2

# Type-based rendering
modelsummary(model1, model2; render = LatexTable())
modelsummary(model1, model2; render = HtmlTable())
modelsummary(model1, model2; render = AsciiTable())
```

**New API**:
```julia
using ModelSummaries

# Symbol-based backend
modelsummary(model1, model2; backend = :latex)
modelsummary(model1, model2; backend = :html)
modelsummary(model1, model2; backend = :text)
modelsummary(model1, model2)  # Auto-detect (default)
```

#### 4. Removed from Public API
The following types are **no longer exported** (but still exist internally):
- `AsciiTable`
- `LatexTable`
- `HtmlTable`
- `AbstractRenderType`

These are kept internally for backward compatibility with the formatting system.

### File Renames

| Old Name | New Name |
|----------|----------|
| `src/RegressionTables2.jl` | `src/ModelSummaries.jl` |
| `src/regtable.jl` | `src/modelsummary.jl` |
| `src/regressiontable.jl` | `src/modelsummary_type.jl` |

### Extension Renames

| Old Name | New Name |
|----------|----------|
| `RegressionTables2CovarianceMatricesExt` | `ModelSummariesCovarianceMatricesExt` |
| `RegressionTables2FixedEffectModelsExt` | `ModelSummariesFixedEffectModelsExt` |
| `RegressionTables2GLMExt` | `ModelSummariesGLMExt` |

### Technical Changes

#### PrettyTables.jl 3.0 Integration
- Updated to use PrettyTables.jl 3.0 API
- Backend selection:
  - `:text` → Uses `:markdown` backend
  - `:html` → Uses `:html` backend
  - `:latex` → Uses `:latex` backend
- Updated parameter names:
  - `header=` → `column_labels=`
  - `header_alignment` → `column_label_alignment`
- Removed unsupported parameters:
  - `body_hlines` removed from markdown backend (only supported in LaTeX)

#### Fixed Compilation Issues
1. Resolved circular dependency between `RegressionStatistics.jl` and `render_compat.jl`
   - Created separate `render_types.jl` for type definitions
   - Moved methods to `render_compat.jl`
2. Fixed `DataRow` constructor to accept `colwidths` parameter
3. Fixed type annotation for `hlines` vector
4. Removed duplicate `default_align()` method definitions

### Migration Guide

#### For Package Users

**Before**:
```julia
using RegressionTables2

rt = modelsummary(m1, m2; render = LatexTable())
```

**After**:
```julia
using ModelSummaries

ms = modelsummary(m1, m2; backend = :latex)
```

#### For Package Developers

If you were extending the package:

**Before**:
```julia
# Custom render type
struct MyTable <: RegressionTables2.AbstractRenderType end
```

**After**:
```julia
# Render types still exist but are internal
# Use backend parameter instead or customize via:
# ModelSummaries.default_breaks(::ModelSummaries.AbstractRenderType)
```

### Backend Options

| Backend | Output Format | Use Case |
|---------|--------------|----------|
| `nothing` | Auto-detect | REPL/Jupyter (default) |
| `:latex` | LaTeX code | Academic papers |
| `:html` | HTML table | Web/Jupyter notebooks |
| `:text` | Markdown | Terminal/text files |

### Customization Functions (Unchanged)

All post-creation customization functions remain the same:
- `add_hline!(ms, position)`
- `remove_hline!(ms, position)`
- `set_alignment!(ms, col, align; header=false)`
- `add_formatter!(ms, formatter)`
- `set_backend!(ms, backend)`
- `merge_kwargs!(ms; kwargs...)`

### Statistics and Export Types (Unchanged)

All statistics types remain exported:
- `Nobs`, `R2`, `AdjR2`, `R2Within`, `PseudoR2`, `AdjPseudoR2`
- `R2McFadden`, `R2CoxSnell`, `R2Nagelkerke`, `R2Deviance`, `AdjR2Deviance`
- `FStat`, `FStatPValue`, `FStatIV`, `FStatIVPValue`
- `DOF`, `LogLikelihood`, `AIC`, `BIC`, `AICC`
- `TStat`, `StdError`, `ConfInt`, `RegressionType`
- `AbstractRegressionStatistic`

### Dependencies

No new dependencies added. Continues to use:
- PrettyTables.jl 3.x
- StatsBase.jl
- StatsModels.jl
- StatsAPI.jl
- Distributions.jl
- Format.jl

---

## Notes

- **Version reset to 0.1.0** due to major breaking changes
- **Author**: Giuseppe Ragusa <giuseppe.ragusa@luiss.it>
- **Original package**: Based on RegressionTables2.jl by Johannes Boehm
