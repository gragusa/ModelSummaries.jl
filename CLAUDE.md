# ModelSummaries.jl

A Julia package for creating publication-quality regression tables from statistical models. Similar to Stata's `esttab` and R's `stargazer`, ModelSummaries.jl generates formatted tables for multiple regression models with support for LaTeX, HTML, and text output.

## Installation

```julia
using Pkg
Pkg.add("ModelSummaries")
```

## Quick Start

```julia
using ModelSummaries, GLM, DataFrames

# Fit some models
df = DataFrame(y = randn(100), x1 = randn(100), x2 = randn(100))
m1 = lm(@formula(y ~ x1), df)
m2 = lm(@formula(y ~ x1 + x2), df)

# Create a regression table
modelsummary(m1, m2)

# Save to file
modelsummary(m1, m2; backend=:latex, file="table.tex")
```

## Supported Model Types

ModelSummaries.jl works with any model implementing the `StatsAPI.RegressionModel` interface. Package extensions provide enhanced support for:

- **GLM.jl** - Linear and generalized linear models
- **FixedEffectModels.jl** - High-dimensional fixed effects models
- **CovarianceMatrices.jl** - Robust standard errors (HC0-HC5, HAC, cluster-robust)

---

## Core API

### `modelsummary(models...; kwargs...)`

The main function for creating regression tables.

```julia
modelsummary(
    models::RegressionModel...;
    # Output control
    backend = nothing,          # :text, :latex, :html, or nothing (auto-detect)
    file = nothing,             # Save to file path

    # Coefficient display
    keep = [],                  # Coefficients to show (String, Regex, Int, Range)
    drop = [],                  # Coefficients to hide
    order = [],                 # Reorder coefficients
    labels = Dict{String,String}(),  # Rename coefficients

    # Statistics below coefficients
    below_statistic = StdError, # StdError, TStat, ConfInt, or nothing
    stat_below = true,          # true: below coefficient, false: same line

    # Table statistics
    regression_statistics = [Nobs, R2],  # Bottom-of-table statistics

    # Formatting
    align = :r,                 # Body column alignment (:l, :c, :r)
    header_align = :c,          # Header alignment
    digits = nothing,           # Decimal places (default: 3)
    stars = false,              # Show significance stars

    # Sections
    print_depvar = true,        # Show dependent variable
    number_regressions = true,  # Number the columns
    print_fe_section = true,    # Show fixed effects section
    print_estimator_section = false,  # Show estimator type

    # Visual styling
    theme = nothing,            # :academic, :modern, :minimal, :compact, :unicode
    table_format = nothing,     # Fine-grained PrettyTables format control

    # Label transformations
    transform_labels = Dict{String,String}(),  # :latex, :ampersand, :underscore
    extralines = nothing,       # Additional rows at table bottom
    groups = nothing,           # Column group headers
)
```

**Returns:** A `ModelSummary` object that displays automatically in REPL/notebooks.

### Output Backends

| Backend | MIME Type | Use Case |
|---------|-----------|----------|
| `:text` | `text/plain` | Terminal, REPL |
| `:latex` | `text/latex` | LaTeX documents |
| `:html` | `text/html` | Jupyter, web pages |
| `:markdown` | `text/plain` | Markdown files |
| `:ascii` | `text/plain` | ASCII-only terminals |

When `backend=nothing`, the output format is auto-detected based on display context.

---

## ModelSummary Type

The `ModelSummary` struct holds table data and formatting options:

```julia
mutable struct ModelSummary
    data::Matrix{Any}              # Table body
    header::Vector{Vector{String}} # Header rows
    header_align::Vector{Symbol}   # Header column alignment
    body_align::Vector{Symbol}     # Body column alignment
    hlines::Vector{Int}            # Horizontal line positions
    formatters::Vector             # PrettyTables formatters
    highlighters::Vector           # PrettyTables highlighters
    backend::Union{Symbol,Nothing} # Rendering backend
    pretty_kwargs::Dict{Symbol,Any}# PrettyTables options
    table_format::Dict{Symbol,Any} # Backend-specific formats
end
```

### Post-Creation Customization

After creating a table, modify it with these functions:

```julia
# Add horizontal line after row 5
add_hline!(ms, 5)

# Remove horizontal line
remove_hline!(ms, 5)

# Change column alignment (body)
set_alignment!(ms, 2, :c)

# Change header alignment
set_alignment!(ms, 2, :l; header=true)

# Force specific backend
set_backend!(ms, :latex)

# Add PrettyTables formatters
add_formatter!(ms, formatter)

# Merge additional PrettyTables options
merge_kwargs!(ms; title="My Results", title_alignment=:c)
```

### Matrix-like Access

```julia
ms = modelsummary(m1, m2)
size(ms)        # (nrows, ncols)
ms[2, 3]        # Access cell
ms[2, 3] = "X"  # Modify cell
```

### File Output

```julia
# Extension determines format
write("table.tex", ms)   # LaTeX
write("table.html", ms)  # HTML
write("table.txt", ms)   # Text
```

---

## Themes

Preset themes provide consistent styling across backends:

```julia
modelsummary(m1, m2; theme=:academic)
```

| Theme | Description |
|-------|-------------|
| `:academic` | Clean, professional (booktabs-style for LaTeX) |
| `:modern` | Unicode rounded corners |
| `:minimal` | Minimalist with fewer borders |
| `:compact` | Space-efficient matrix style |
| `:unicode` | Double-line unicode borders |
| `:default` | Alias for `:academic` |

### Custom Themes

```julia
using PrettyTables

my_theme = Dict(
    :text => PrettyTables.TextTableFormat(),
    :latex => PrettyTables.latex_table_format__booktabs,
    :html => PrettyTables.HtmlTableFormat(),
)
modelsummary(m1, m2; theme=my_theme)
```

### Theme Discovery

```julia
using ModelSummaries.Themes
Themes.list_themes()
```

---

## Custom Covariance Matrices

Override standard errors with the `vcov()` function and `+` operator:

### Direct Matrix

```julia
Σ = [0.01 0; 0 0.02]
modelsummary(model + vcov(Σ))
```

### Function

```julia
modelsummary(model + vcov(m -> custom_vcov_computation(m)))
```

### CovarianceMatrices.jl Integration

```julia
using CovarianceMatrices

# Heteroskedasticity-robust (HC3)
modelsummary(model + vcov(HC3()))

# HAC standard errors
modelsummary(model + vcov(Bartlett(5)))

# Multiple models with different vcov
modelsummary(
    model1 + vcov(HC0()),
    model2 + vcov(HC3()),
    model3 + vcov(Parzen(3))
)
```

### Custom Estimator Extension

```julia
struct MyEstimator end

function ModelSummaries.materialize_vcov(::MyEstimator, model)
    # Return covariance matrix
    return compute_my_vcov(model)
end

modelsummary(model + vcov(MyEstimator()))
```

---

## Regression Statistics

Built-in statistics for the table footer:

| Type | Description |
|------|-------------|
| `Nobs` | Number of observations |
| `R2` | R-squared |
| `AdjR2` | Adjusted R-squared |
| `R2Within` | Within R-squared (fixed effects) |
| `PseudoR2` | McFadden pseudo R-squared |
| `R2McFadden` | Same as PseudoR2 |
| `R2CoxSnell` | Cox-Snell R-squared |
| `R2Nagelkerke` | Nagelkerke R-squared |
| `R2Deviance` | Deviance R-squared |
| `AdjPseudoR2` | Adjusted pseudo R-squared |
| `AdjR2Deviance` | Adjusted deviance R-squared |
| `DOF` | Degrees of freedom |
| `LogLikelihood` | Log-likelihood |
| `AIC` | Akaike information criterion |
| `AICC` | Corrected AIC |
| `BIC` | Bayesian information criterion |
| `FStat` | F-statistic |
| `FStatPValue` | F-statistic p-value |
| `FStatIV` | First-stage F-statistic (IV) |
| `FStatIVPValue` | First-stage F p-value (IV) |

```julia
modelsummary(m1, m2; regression_statistics=[Nobs, R2, AdjR2, AIC, BIC])
```

### Symbol Shortcuts

```julia
modelsummary(m1, m2; regression_statistics=[:nobs, :r2, :adjr2, :f, :p])
```

### Custom Statistics

```julia
struct YMean <: ModelSummaries.AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end

YMean(model::RegressionModel) = try
    YMean(mean(response(model)))
catch
    YMean(nothing)
end

ModelSummaries.label(::ModelSummaries.AbstractRenderType, ::Type{YMean}) = "Mean of Y"

modelsummary(m1, m2; regression_statistics=[Nobs, R2, YMean])
```

---

## Below-Coefficient Statistics

| Type | Description |
|------|-------------|
| `StdError` | Standard error (default) |
| `TStat` | t-statistic |
| `ConfInt` | Confidence interval |
| `nothing` | No statistic below |

```julia
modelsummary(m1, m2; below_statistic=TStat)
modelsummary(m1, m2; below_statistic=ConfInt, confint_level=0.99)
modelsummary(m1, m2; below_statistic=nothing)  # Coefficients only
```

---

## Coefficient Selection

### Keep Specific Coefficients

```julia
modelsummary(m1, m2; keep=["x1", "x2"])
modelsummary(m1, m2; keep=[r"x"])           # Regex
modelsummary(m1, m2; keep=[1, 2])           # By index
modelsummary(m1, m2; keep=[1:3])            # Range
```

### Drop Coefficients

```julia
modelsummary(m1, m2; drop=["(Intercept)"])
modelsummary(m1, m2; drop=[r"fe_"])         # Drop fixed effect dummies
```

### Reorder Coefficients

```julia
modelsummary(m1, m2; order=["x2", "x1", "(Intercept)"])
modelsummary(m1, m2; order=[r" & "])        # Interactions first
```

---

## Label Customization

### Coefficient Labels

```julia
modelsummary(m1, m2; labels=Dict(
    "x1" => "Treatment",
    "x2" => "Control",
    "(Intercept)" => "Constant"
))
```

### Label Transformations

```julia
# Escape LaTeX special characters
modelsummary(m1, m2; transform_labels=:latex)

# Replace & with "and"
modelsummary(m1, m2; transform_labels=:ampersand)

# Replace underscores with spaces
modelsummary(m1, m2; transform_labels=:underscore2space)
```

---

## Column Groups

```julia
# Single row of groups
modelsummary(m1, m2, m3, m4;
    groups=["Sample A" "Sample A" "Sample B" "Sample B"]
)

# Multi-row groups
modelsummary(m1, m2, m3, m4;
    groups=[
        ["2020" "2020" "2021" "2021"],
        ["Men" "Women" "Men" "Women"]
    ]
)
```

---

## Extra Lines

Add custom rows at the table bottom:

```julia
modelsummary(m1, m2;
    extralines=[
        ["Sample", "Full", "Restricted"],
        ["Controls", "Yes", "Yes"]
    ]
)
```

---

## Formatting Options

### Number Formatting

```julia
modelsummary(m1, m2;
    digits=4,                    # Coefficient precision
    digits_stats=2,              # Statistics precision
    estimformat="%0.4f",         # Printf format for coefficients
    statisticformat="%0.2f"      # Printf format for statistics
)
```

### Significance Stars

```julia
modelsummary(m1, m2; stars=true)
# *** p<0.01, ** p<0.05, * p<0.1
```

### Custom Decorations

```julia
# Custom coefficient decoration
function my_decorator(value::String, pval::Float64)
    pval < 0.05 ? "$value†" : value
end
modelsummary(m1, m2; estim_decoration=my_decorator)

# Custom below-statistic decoration
modelsummary(m1, m2; below_decoration=s -> "[$s]")

# Custom regression numbering
modelsummary(m1, m2; number_regressions_decoration=i -> "Model $i")
```

---

## Customizing Defaults

Override default behavior by defining methods on `AbstractRenderType`:

```julia
# Change default digits
ModelSummaries.default_digits(::ModelSummaries.AbstractRenderType, x) = 4

# Change default statistics
ModelSummaries.default_regression_statistics(::ModelSummaries.AbstractRenderType, rrs) = [Nobs, R2, AdjR2]

# Change default below statistic
ModelSummaries.default_below_statistic(::ModelSummaries.AbstractRenderType) = TStat

# LaTeX-specific defaults
ModelSummaries.default_transform_labels(::ModelSummaries.AbstractLatex, rrs) = :latex
```

---

## PrettyTables Integration

`ModelSummary` uses PrettyTables.jl 3.x for rendering. Access all PrettyTables features:

```julia
ms = modelsummary(m1, m2)

# Direct kwargs access
ms.pretty_kwargs[:title] = "Regression Results"
ms.pretty_kwargs[:title_alignment] = :c

# Or use merge_kwargs!
merge_kwargs!(ms;
    title="Results",
    vcrop_mode=:middle,
    crop_num_lines_at_end=10
)
```

### Backend-Specific Formats

PrettyTables 3.x uses backend-specific format types:

- `LatexTableFormat` for LaTeX
- `TextTableFormat` for text
- `MarkdownTableFormat` for markdown
- `HtmlTableFormat` for HTML

```julia
ms = modelsummary(m1, m2;
    table_format=Dict(
        :latex => PrettyTables.latex_table_format__booktabs,
        :text => PrettyTables.text_table_format__matrix
    )
)
```

---

## Project Structure

```
ModelSummaries.jl/
├── src/
│   ├── ModelSummaries.jl      # Main module
│   ├── modelsummary.jl        # modelsummary() function
│   ├── modelsummary_type.jl   # ModelSummary struct
│   ├── RegressionStatistics.jl # Nobs, R2, etc.
│   ├── regressionResults.jl   # Model interface, vcov
│   ├── coefnames.jl           # Coefficient name handling
│   ├── themes.jl              # Theme presets
│   ├── compat/                # Render type compatibility
│   ├── decorations/           # Stars, formatting
│   └── label_transforms/      # Label escaping
├── ext/
│   ├── ModelSummariesGLMExt.jl
│   ├── ModelSummariesFixedEffectModelsExt.jl
│   └── ModelSummariesCovarianceMatricesExt.jl
└── test/
```

---

## Dependencies

**Required:**
- PrettyTables.jl (>= 3.0)
- StatsAPI.jl
- StatsBase.jl
- StatsModels.jl
- Distributions.jl
- Format.jl

**Optional (extensions):**
- GLM.jl
- FixedEffectModels.jl
- CovarianceMatrices.jl

---

## Examples

### Basic Table

```julia
using ModelSummaries, GLM, DataFrames

df = DataFrame(
    y = randn(100),
    x1 = randn(100),
    x2 = randn(100),
    group = rand(1:3, 100)
)

m1 = lm(@formula(y ~ x1), df)
m2 = lm(@formula(y ~ x1 + x2), df)

modelsummary(m1, m2)
```

### Publication-Ready LaTeX

```julia
modelsummary(m1, m2;
    backend=:latex,
    file="results.tex",
    labels=Dict(
        "x1" => "Treatment",
        "x2" => "Control",
        "(Intercept)" => "Constant"
    ),
    regression_statistics=[Nobs, R2, AdjR2],
    stars=true,
    transform_labels=:latex
)
```

### Fixed Effects with Robust SE

```julia
using FixedEffectModels, CovarianceMatrices

fe1 = reg(df, @formula(y ~ x1 + fe(group)))
fe2 = reg(df, @formula(y ~ x1 + x2 + fe(group)))

modelsummary(
    fe1 + vcov(HC3()),
    fe2 + vcov(HC3());
    regression_statistics=[Nobs, R2, R2Within]
)
```

### Grouped Columns

```julia
modelsummary(m1, m2, m1, m2;
    groups=["OLS" "OLS" "Robust" "Robust"],
    labels=Dict("x1" => "Main Effect")
)
```
