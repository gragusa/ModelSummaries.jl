# PrettyTables.jl Integration Guide

ModelSummaries.jl uses [PrettyTables.jl 3.0](https://ronisbr.github.io/PrettyTables.jl/stable/) as its rendering backend. This means you have access to the full power of PrettyTables.jl for customizing your regression tables.

## Table of Contents

- [Quick Start](#quick-start)
- [Using Themes](#using-themes)
- [Customizing with PrettyTables Features](#customizing-with-prettytables-features)
  - [Formatters](#formatters)
  - [Highlighters](#highlighters)
  - [Table Formats](#table-formats)
  - [Titles and Captions](#titles-and-captions)
- [Horizontal Lines](#horizontal-lines)
- [Direct Access to PrettyTables Options](#direct-access-to-prettytables-options)
- [Advanced Examples](#advanced-examples)

---

## Quick Start

The simplest way to create a regression table:

```julia
using ModelSummaries, GLM, DataFrames

# Fit models
data = DataFrame(x = randn(100), y = randn(100), z = randn(100))
m1 = lm(@formula(y ~ x), data)
m2 = lm(@formula(y ~ x + z), data)

# Create table (auto-detects output format)
modelsummary(m1, m2)
```

This automatically:
- Detects the output context (terminal, Jupyter, LaTeX)
- Applies appropriate formatting
- Uses sensible defaults

---

## Using Themes

ModelSummaries.jl provides beautiful preset themes for different use cases:

### Available Themes

```julia
# Academic publication style (default)
modelsummary(m1, m2; theme=:academic)

# Modern style with unicode box-drawing
modelsummary(m1, m2; theme=:modern)

# Minimalist style
modelsummary(m1, m2; theme=:minimal)

# Compact style for dense tables
modelsummary(m1, m2; theme=:compact)

# Clean unicode tables
modelsummary(m1, m2; theme=:unicode)
```

### Theme Comparison

| Theme      | Best For                          | Text Output    | LaTeX         |
|------------|-----------------------------------|----------------|---------------|
| `:academic`| Journal articles, dissertations   | Markdown       | Booktabs      |
| `:modern`  | Presentations, reports            | Unicode rounded| Modern LaTeX  |
| `:minimal` | Simple tables, documentation      | Simple ASCII   | Simple LaTeX  |
| `:compact` | Large tables, space-constrained   | Compact ASCII  | Simple LaTeX  |
| `:unicode` | Terminal output, REPLs            | Unicode boxes  | Booktabs      |

### Custom Themes

You can create your own theme by providing a dictionary mapping backends to PrettyTables `TableFormat` objects:

```julia
using PrettyTables

my_theme = Dict(
    :text => PrettyTables.tf_unicode_rounded,
    :html => PrettyTables.tf_html_dark,
    :latex => PrettyTables.tf_latex_modern
)

modelsummary(m1, m2; theme=my_theme)
```

Or as a NamedTuple:

```julia
my_theme = (
    text = PrettyTables.tf_unicode,
    html = PrettyTables.tf_html_simple,
    latex = PrettyTables.tf_latex_booktabs
)

modelsummary(m1, m2; theme=my_theme)
```

---

## Customizing with PrettyTables Features

### Formatters

PrettyTables formatters allow you to customize how values are displayed.

#### Example: Custom Number Formatting

```julia
using PrettyTables

rt = modelsummary(m1, m2)

# Format specific columns with 4 decimal places
merge_kwargs!(rt; formatters = ft_printf("%.4f", [2, 3]))
```

#### Example: Conditional Formatting

```julia
# Bold values greater than 2.0
formatter = (v, i, j) -> begin
    if isa(v, Float64) && v > 2.0
        return "**$(v)**"
    end
    return v
end

merge_kwargs!(rt; formatters = formatter)
```

### Highlighters

Highlighters change the appearance of cells based on their content or position.

#### Example: Highlight Significant Results

```julia
using PrettyTables, Crayons

# Highlight cells containing *** (p < 0.01) in bold green
h = Highlighter(
    f = (data, i, j) -> j > 1 && contains(string(data[i, j]), "***"),
    crayon = crayon"bold green"
)

merge_kwargs!(rt; highlighters = h)
```

#### Example: Zebra Stripes

```julia
# Alternate row colors for better readability
h1 = Highlighter(
    f = (data, i, j) -> isodd(i),
    crayon = crayon"bg:light_gray"
)
h2 = Highlighter(
    f = (data, i, j) -> iseven(i),
    crayon = crayon"bg:white"
)

merge_kwargs!(rt; highlighters = (h1, h2))
```

### Table Formats

For fine-grained control, you can specify different `TableFormat` objects for each backend:

```julia
# Use unicode rounded for terminal, booktabs for LaTeX
modelsummary(m1, m2;
    table_format = Dict(
        :text => PrettyTables.tf_unicode_rounded,
        :latex => PrettyTables.tf_latex_booktabs,
        :html => PrettyTables.tf_html_minimalist
    )
)
```

### Titles and Captions

```julia
rt = modelsummary(m1, m2)

# Add title
merge_kwargs!(rt;
    title = "Regression Results",
    title_alignment = :c
)
```

For LaTeX, you can use captions and labels:

```julia
merge_kwargs!(rt;
    table_type = :table,
    label = "tab:results",
    caption = "Regression results for X and Z"
)
```

---

## Horizontal Lines

Add horizontal lines to separate sections of your table:

```julia
rt = modelsummary(m1, m2)

# Add horizontal line after row 3
add_hline!(rt, 3)

# Add multiple lines
add_hline!(rt, 5)
add_hline!(rt, 8)

# Remove a line
remove_hline!(rt, 5)
```

Horizontal lines work across all backends (text/Markdown, HTML, and LaTeX).

---

## Direct Access to PrettyTables Options

For maximum flexibility, you can directly access and modify the `pretty_kwargs` dictionary:

```julia
rt = modelsummary(m1, m2)

# Direct access to any PrettyTables option
rt.pretty_kwargs[:body_hlines] = [3, 5, 7]
rt.pretty_kwargs[:crop_num_lines_at_end] = 10
rt.pretty_kwargs[:vcrop_mode] = :middle

# Display the modified table
display(rt)
```

This gives you access to **all** PrettyTables.jl options without needing wrapper functions. See the [PrettyTables.jl documentation](https://ronisbr.github.io/PrettyTables.jl/stable/) for the full list of available options.

---

## Advanced Examples

### Example 1: Publication-Ready LaTeX Table

```julia
rt = modelsummary(m1, m2, m3;
    backend = :latex,
    theme = :academic,
    regression_statistics = [Nobs, R2, AdjR2, FStat],
    below_statistic = StdError
)

# Add professional touches
add_hline!(rt, 4)  # Separate coefficients from statistics
merge_kwargs!(rt;
    table_type = :table,
    label = "tab:main_results",
    caption = "Main regression results",
    wrap_table = true
)

# Save to file
write("main_results.tex", rt)
```

### Example 2: Colorful Terminal Output

```julia
using Crayons

rt = modelsummary(m1, m2;
    theme = :modern,
    backend = :text
)

# Color-code significance levels
h_high = Highlighter(
    f = (data, i, j) -> contains(string(data[i, j]), "***"),
    crayon = crayon"bold green"
)
h_medium = Highlighter(
    f = (data, i, j) -> contains(string(data[i, j]), "**") && !contains(string(data[i, j]), "***"),
    crayon = crayon"bold yellow"
)
h_low = Highlighter(
    f = (data, i, j) -> contains(string(data[i, j]), "*") && !contains(string(data[i, j]), "**"),
    crayon = crayon"yellow"
)

merge_kwargs!(rt; highlighters = (h_high, h_medium, h_low))
```

### Example 3: HTML Table with Custom Styling

```julia
rt = modelsummary(m1, m2;
    backend = :html,
    theme = :minimal
)

merge_kwargs!(rt;
    standalone = false,  # Don't include <html> wrapper
    table_style = Dict(
        "border" => "1px solid black",
        "border-collapse" => "collapse"
    ),
    header_cell_style = Dict(
        "background-color" => "#f0f0f0",
        "font-weight" => "bold"
    )
)

write("results.html", rt)
```

### Example 4: Compact Table for Large Models

```julia
# Many regressors, need to save space
rt = modelsummary(large_m1, large_m2, large_m3;
    theme = :compact,
    keep = [:x, :z, :treatment],  # Only show key variables
    regression_statistics = [Nobs, R2],  # Minimal statistics
)

# Further compress
merge_kwargs!(rt;
    compact_printing = true,
    linebreaks = true,
    autowrap = true,
    columns_width = [20, 10, 10, 10]
)
```

### Example 5: Side-by-Side Comparison

```julia
# Create two separate tables
rt1 = modelsummary(m1_a, m1_b; theme=:academic)
rt2 = modelsummary(m2_a, m2_b; theme=:academic)

# Customize each
merge_kwargs!(rt1; title="Panel A: Main Sample")
merge_kwargs!(rt2; title="Panel B: Robustness Check")

# Display both
display(rt1)
println("\n")
display(rt2)
```

### Example 6: Method Chaining

All modification functions return the table, allowing for method chaining:

```julia
rt = modelsummary(m1, m2) |>
    (rt -> add_hline!(rt, 3)) |>
    (rt -> set_alignment!(rt, 2, :c)) |>
    (rt -> set_backend!(rt, :latex)) |>
    (rt -> merge_kwargs!(rt; title="Results"))
```

Or more simply:

```julia
rt = modelsummary(m1, m2)
add_hline!(rt, 3)
set_alignment!(rt, 2, :c)
set_backend!(rt, :latex)
merge_kwargs!(rt; title="Results")
# All functions modify rt in place and return it
```

---

## Complete Function Reference

### Table Creation

- `modelsummary(models...; kwargs...)` - Create regression table

### Post-Creation Modification

- `add_hline!(rt, position)` - Add horizontal line
- `remove_hline!(rt, position)` - Remove horizontal line
- `set_alignment!(rt, col, align; header=false)` - Change column alignment
- `add_formatter!(rt, formatter)` - Add PrettyTables formatter
- `set_backend!(rt, backend)` - Change rendering backend
- `merge_kwargs!(rt; kwargs...)` - Add any PrettyTables options

### File Output

- `write(filename, rt)` - Save table to file

---

## See Also

- [PrettyTables.jl Documentation](https://ronisbr.github.io/PrettyTables.jl/stable/)
- [PrettyTables.jl Formatters Guide](https://ronisbr.github.io/PrettyTables.jl/stable/man/formatters/)
- [PrettyTables.jl Highlighters Guide](https://ronisbr.github.io/PrettyTables.jl/stable/man/highlighters/)
- [PrettyTables.jl Text Backend](https://ronisbr.github.io/PrettyTables.jl/stable/man/text_backend/)
- [PrettyTables.jl HTML Backend](https://ronisbr.github.io/PrettyTables.jl/stable/man/html_backend/)
- [PrettyTables.jl LaTeX Backend](https://ronisbr.github.io/PrettyTables.jl/stable/man/latex_backend/)

---

## Tips and Best Practices

1. **Start Simple**: Use preset themes first, only customize when needed
2. **Leverage PrettyTables**: Don't reinvent the wheel - use PrettyTables features directly
3. **Test Output**: Check how your table looks in all target formats (terminal, LaTeX, HTML)
4. **Use Themes**: Themes ensure consistent styling across backends
5. **Document Custom Themes**: If you create custom themes, document them for reproducibility
6. **Chain Modifications**: Build up complex tables step-by-step with chaining

---

**Version**: 1.0
**Last Updated**: 2025-01-14
**Compatible with**: ModelSummaries.jl v1.0+, PrettyTables.jl v3.0+
