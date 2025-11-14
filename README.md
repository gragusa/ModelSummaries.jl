# ModelSummaries.jl

[![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url]

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://gragusa.github.io/ModelSummaries.jl/stable
[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://gragusa.github.io/ModelSummaries.jl/dev

Create publication-quality regression tables in Julia with a simple, modern API.

**ModelSummaries.jl** (formerly RegressionTables2.jl) provides beautiful regression tables for use with [FixedEffectModels.jl](https://github.com/matthieugomez/FixedEffectModels.jl), [GLM.jl](https://github.com/JuliaStats/GLM.jl), and any package that implements the [RegressionModel abstraction](https://juliastats.org/StatsBase.jl/latest/statmodels/).

## Installation

```julia
using Pkg
Pkg.add("github.com/gragusa/ModelSummaries.jl")
```

## Quick Start

```julia
using ModelSummaries, GLM, DataFrames, RDatasets

# Load data
df = dataset("datasets", "iris")

# Fit models
m1 = lm(@formula(SepalLength ~ SepalWidth), df)
m2 = lm(@formula(SepalLength ~ SepalWidth + PetalLength), df)
m3 = lm(@formula(SepalLength ~ SepalWidth + PetalLength + PetalWidth), df)

# Create a regression table (auto-detects output format)
modelsummary(m1, m2, m3)
```

Output:
```
|                  | **Model 1** | **Model 2** | **Model 3** |
|:-----------------|------------:|------------:|------------:|
| (Intercept)      |       6.526 |       4.191 |       1.856 |
|                  |      (0.479)|      (0.410)|      (0.251)|
| SepalWidth       |      -0.223 |      -0.094 |       0.650 |
|                  |      (0.155)|      (0.132)|      (0.067)|
| PetalLength      |             |       0.472 |       0.712 |
|                  |             |      (0.017)|      (0.057)|
| PetalWidth       |             |             |      -0.556 |
|                  |             |             |      (0.128)|
| N                |         150 |         150 |         150 |
| R²               |       0.014 |       0.759 |       0.837 |
```

## Output Formats

Control output format with the `backend` parameter:

```julia
# LaTeX output
modelsummary(m1, m2; backend=:latex, file="table.tex")

# HTML output
modelsummary(m1, m2; backend=:html, file="table.html")

# Markdown/text output
modelsummary(m1, m2; backend=:text)

# Auto-detect based on context (default)
modelsummary(m1, m2)  # Uses markdown in REPL, HTML in Jupyter
```

## Custom Covariance Matrices

Use robust standard errors with [CovarianceMatrices.jl](https://github.com/gragusa/CovarianceMatrices.jl):

```julia
using CovarianceMatrices

# HC1 robust standard errors
modelsummary(m1 + vcov(HC1()), m2 + vcov(HC1()))

# Cluster-robust standard errors
modelsummary(m1 + vcov(CRHC0(cluster_var)))

# HAC standard errors
modelsummary(m1 + vcov(HAC(NeweyWest, 4)))
```

Available covariance estimators:
- `HC0()`, `HC1()`, `HC2()`, `HC3()`, `HC4()`, `HC5()` - Heteroskedasticity-robust
- `HAC(kernel, bandwidth)` - Heteroskedasticity and autocorrelation consistent
- `CRHC0(clusters)`, `CRHC1(clusters)`, etc. - Cluster-robust

## Customization

### Statistics and Labels

```julia
modelsummary(m1, m2, m3;
    # Select statistics to display
    regression_statistics = [Nobs, R2, AdjR2, FStat],

    # Custom variable labels
    labels = Dict(
        "SepalWidth" => "Sepal Width (cm)",
        "PetalLength" => "Petal Length (cm)"
    ),

    # Below-coefficient statistic
    below_statistic = TStat,  # or StdError, ConfInt

    # Significance levels
    confint_level = 0.90
)
```

### Alignment and Formatting

```julia
modelsummary(m1, m2;
    align = :c,           # Column alignment: :l, :c, :r
    header_align = :l,    # Header alignment
    digits = 4,           # Coefficient precision
    digits_stats = 2      # Statistics precision
)
```

### Variable Selection and Ordering

```julia
modelsummary(m1, m2, m3;
    keep = ["SepalWidth", "PetalLength"],  # Only show these
    drop = ["(Intercept)"],                 # Exclude these
    order = ["PetalLength", "SepalWidth"]  # Custom order
)
```

### Post-Creation Customization

Tables can be modified after creation:

```julia
# Create table
ms = modelsummary(m1, m2, m3)

# Add horizontal lines
add_hline!(ms, 3)  # Add line after row 3
add_hline!(ms, 6)

# Change backend
set_backend!(ms, :latex)

# Change column alignment
set_alignment!(ms, 2, :c)  # Center column 2

# Add custom formatters (uses PrettyTables.jl)
using PrettyTables
formatter = ft_printf("%.4f", [2, 3])  # 4 decimals in columns 2-3
add_formatter!(ms, formatter)

# Pass additional PrettyTables options
merge_kwargs!(ms;
    title = "Regression Results",
    title_alignment = :c
)

# Save to file
write("table.tex", ms)
```

## Complete Example

```julia
using ModelSummaries, FixedEffectModels, GLM, DataFrames, RDatasets

df = dataset("datasets", "iris")

# Fit various models
rr1 = reg(df, @formula(SepalLength ~ SepalWidth + fe(Species)))
rr2 = reg(df, @formula(SepalLength ~ SepalWidth + PetalLength + fe(Species)))
rr3 = reg(df, @formula(SepalLength ~ SepalWidth * PetalLength + PetalWidth + fe(Species)))
m4 = lm(@formula(SepalWidth ~ SepalLength + PetalLength + PetalWidth), df)

# Create comprehensive table
modelsummary(rr1, rr2, rr3, m4;
    # Output format
    backend = :latex,
    file = "results.tex",

    # Variable labels
    labels = Dict(
        "SepalWidth" => "Sepal Width",
        "PetalLength" => "Petal Length",
        "PetalWidth" => "Petal Width"
    ),

    # Statistics
    regression_statistics = [
        Nobs => "Observations",
        R2 => "R²",
        R2Within => "Within R²",
        AdjR2 => "Adjusted R²"
    ],

    # Formatting
    below_statistic = StdError,
    digits = 3,

    # Fixed effects
    print_fe_section = true,
    fixedeffects = ["Species"],

    # Variable ordering
    order = [r"Int", r" & ", r": "]
)
```

## API Reference

### Main Function

```julia
modelsummary(
    models::RegressionModel...;

    # Output format
    backend = nothing,              # :latex, :html, :text, or nothing (auto)
    file = nothing,                 # Output file path

    # Variable selection
    keep = [],                      # Variables to include
    drop = [],                      # Variables to exclude
    order = [],                     # Variable ordering

    # Labels and formatting
    labels = Dict{String,String}(), # Variable labels
    align = :r,                     # Column alignment
    header_align = :c,              # Header alignment
    digits = nothing,               # Coefficient digits (default: 3)
    digits_stats = nothing,         # Statistics digits (default: 3)

    # Statistics
    below_statistic = StdError,     # TStat, StdError, ConfInt, or nothing
    regression_statistics = [Nobs, R2],  # Bottom statistics
    confint_level = 0.95,          # Confidence level

    # Display options
    print_depvar = true,            # Show dependent variable
    number_regressions = true,      # Number columns
    print_fe_section = true,        # Show fixed effects section
    print_estimator_section = false # Show estimator section
)
```

### Customization Functions

- `add_hline!(ms, position)` - Add horizontal line
- `remove_hline!(ms, position)` - Remove horizontal line
- `set_alignment!(ms, col, align; header=false)` - Change column alignment
- `set_backend!(ms, backend)` - Change output backend
- `add_formatter!(ms, formatter)` - Add PrettyTables formatter
- `merge_kwargs!(ms; kwargs...)` - Add PrettyTables options

### Available Statistics

**Goodness of fit**:
- `Nobs` - Number of observations
- `R2` - R²
- `AdjR2` - Adjusted R²
- `R2Within` - Within R²
- `PseudoR2` - Pseudo R² (for GLMs)

**Model fit**:
- `LogLikelihood` - Log-likelihood
- `AIC` - Akaike information criterion
- `BIC` - Bayesian information criterion
- `AICC` - Corrected AIC

**Tests**:
- `FStat` - F-statistic
- `FStatPValue` - F-test p-value
- `DOF` - Degrees of freedom

### Backend Options

| Backend | Format | Use Case |
|---------|--------|----------|
| `nothing` | Auto-detect | REPL/Jupyter |
| `:latex` | LaTeX | Academic papers |
| `:html` | HTML | Web/notebooks |
| `:text` | Markdown | Terminal/docs |

## Migration from RegressionTables2.jl

If you're migrating from the old API:

**Old**:
```julia
using RegressionTables2
regtable(m1, m2; render=LatexTable())
```

**New**:
```julia
using ModelSummaries
modelsummary(m1, m2; backend=:latex)
```

See [CHANGELOG.md](CHANGELOG.md) for complete migration guide.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Related Packages

- [RegressionTables.jl](https://github.com/jmboehm/RegressionTables.jl) - Original package
- [CovarianceMatrices.jl](https://github.com/gragusa/CovarianceMatrices.jl) - Robust covariance estimators
- [FixedEffectModels.jl](https://github.com/matthieugomez/FixedEffectModels.jl) - Fast fixed effects estimation
- [GLM.jl](https://github.com/JuliaStats/GLM.jl) - Generalized linear models
- [PrettyTables.jl](https://github.com/ronisbr/PrettyTables.jl) - Table rendering (used internally)

## License

MIT License - see [LICENSE.md](LICENSE.md)

## Aknowledgment

**Johannes Boehm**, author of `RegressionTables.jl`, should be credited for all the good things here. 
