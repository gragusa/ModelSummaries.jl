# ModelSummaries.jl

`ModelSummaries.jl` builds publication-ready regression tables with a compact API.

## Quick usage

```julia
using ModelSummaries

ms = modelsummary(m1, m2; theme=:academic)
```

## Backends

Model summaries can be rendered using:

- `:text`
- `:ascii`
- `:markdown`
- `:html`
- `:latex`
- `:typst`

Example:

```julia
modelsummary(m1, m2; backend=:typst, file="table.typ")
```

## Themes and customization

For most users, start with a theme:

```julia
modelsummary(m1, m2; theme=:modern)
```

For economics/journal-style output, use:

```julia
modelsummary(m1, m2; theme=:academic, backend=:latex, file="table.tex")
modelsummary(m1, m2; theme=:academic, backend=:typst, file="table.typ")
```

Then customize only what you need with `table_format`:

```julia
using PrettyTables

modelsummary(m1, m2;
    table_format=Dict(
        :text => PrettyTables.text_table_format__matrix,
        :latex => PrettyTables.latex_table_format__booktabs
    )
)
```

### Theme tips

- `theme` is for quick presets.
- `table_format` is for backend-specific control.
- If both are provided, `theme` takes precedence.

## API design goals

The package API is intentionally utility-focused:

- a single entry point (`modelsummary`) for common cases;
- predictable keyword-based customization;
- post-processing helpers (`set_backend!`, `add_hline!`, `merge_kwargs!`) for iterative workflows.

## Current improvement opportunities

- Expand docs with a full "themes cookbook" (examples for each built-in theme and custom theme patterns).
- Add dedicated Typst examples and reference outputs in tests.
- Continue reducing type-instability hotspots where table cells are stored as `Any` during construction.
