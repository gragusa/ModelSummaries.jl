# ModelSummaries.jl

[![CI](https://github.com/gragusa/ModelSummaries.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/gragusa/ModelSummaries.jl/actions/workflows/CI.yml) [![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl) ![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)

Publication-quality regression tables for Julia, powered by [SummaryTables.jl](https://github.com/PumasAI/SummaryTables.jl).

Tables render natively to **LaTeX**, **HTML**, **Typst**, and **DOCX** — with proper math typesetting in every backend.

## Supported models

| Package | Extension loaded automatically |
|---------|-------------------------------|
| [GLM.jl](https://github.com/JuliaStats/GLM.jl) | `lm`, `glm` |
| [FixedEffectModels.jl](https://github.com/matthieugomez/FixedEffectModels.jl) | `reg` (FE, IV, clusters) |
| [Regress.jl](https://gragusa.org/gragusa/Regress.jl) | OLS, IV, FE, clusters |
| [CovarianceMatrices.jl](https://github.com/gragusa/CovarianceMatrices.jl) | `model + vcov(HC3())` syntax |
| Any `StatsAPI.RegressionModel` | Basic support out of the box |

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/gragusa/ModelSummaries.jl")
```

## Quick start

```julia
using ModelSummaries, GLM, DataFrames, RDatasets, Regress

df = dataset("datasets", "iris")
m1 = lm(@formula(SepalLength ~ SepalWidth), df)
m2 = lm(@formula(SepalLength ~ SepalWidth + PetalLength), df)
m3 = lm(@formula(SepalLength ~ SepalWidth + PetalLength + PetalWidth), df)
m4 = Regress.ols(df, SepalLength ~ SepalWidth + PetalLength + PetalWidth + fe(species))

modelsummary(m1, m2, m3, m4)
```

## Robust and clustered standard errors

Pair any fitted model with a covariance estimator using `+`:

```julia
using CovarianceMatrices

modelsummary(m2, m2 + vcov(HC0()), m2 + vcov(HC3());
    regression_statistics = [Nobs, R2, AdjR2, VcovType],
)
```

## Math labels with `BackendMath`

Labels can include LaTeX math that renders correctly across all backends.
Only the `latex` argument is needed — HTML, Typst, and text are derived
automatically:

```julia
modelsummary(m1, m2;
    labels = Dict(
        "SepalWidth"  => BackendMath(raw"Sepal width ($\beta_1$)"),
        "PetalLength" => BackendMath(raw"Petal length ($\beta_2$)"),
    ),
)
```

Override any backend explicitly when auto-conversion isn't enough:

```julia
BackendMath(
    latex = raw"$\hat{\sigma}^2$",
    typst = raw"$hat(sigma)^2$",
    html  = "&sigma;&#x0302;<sup>2</sup>",
)
```

## Fixed effects

```julia
using FixedEffectModels, CategoricalArrays

fe1 = reg(df, @formula(SepalLength ~ SepalWidth + fe(Species)))

modelsummary(m1, fe1;
    yes_indicator = Checkmark,   # renders as \checkmark (LaTeX), ✓ (HTML/Typst)
    labels = Dict("isSmall" => "Small"),
)
```

## Key options

```julia
modelsummary(models...;
    # Coefficient selection
    keep = [],  drop = [],  order = [],

    # Labels
    labels = Dict("var" => "Label"),          # plain strings or BackendMath
    transform_labels = Dict("old" => "new"),  # regex replacements

    # Header
    groups = ["G1" "G1" "G2"],
    estimator_names = ["OLS", "FE", "IV"],
    depvar_bold = false,

    # Below coefficients
    below_statistic = StdError,  # or TStat, ConfInt, nothing
    stars = false,

    # Bottom statistics
    regression_statistics = [Nobs, R2, AdjR2, AIC, BIC, VcovType],
    digits = 3,
    digits_stats = 3,

    # Fixed effects
    yes_indicator = Checkmark,  # or "Yes", or any BackendMath
    print_fe_suffix = true,

    # Custom rows and footnotes
    custom_lines = ["Sample" => ["Full", "Full"]],
    footnotes = ["Note: ..."],

    # Output
    file = "table.tex",  # .tex, .html, .typ, .docx
)
```

## Available statistics

| Type | Label | Notes |
|------|-------|-------|
| `Nobs` | N | |
| `R2` | R² | |
| `AdjR2` | Adjusted R² | |
| `R2Within` | Within-R² | FE models |
| `R2McFadden` | Pseudo R² | GLMs |
| `AIC`, `BIC`, `AICC` | Information criteria | |
| `LogLikelihood` | Log Likelihood | |
| `FStat`, `FStatPValue` | F-statistic | |
| `FStatIV`, `FStatIVPValue` | First-stage F | IV models |
| `DOF` | Degrees of Freedom | |
| `VcovType` | Std. Error | Shows estimator name |

## Defining custom statistics

```julia
struct YMean <: ModelSummaries.AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
YMean(x::RegressionModel) = try YMean(mean(response(x))) catch; YMean(nothing) end
ModelSummaries.label(::Type{YMean}) = "Mean of Y"

modelsummary(m1; regression_statistics = [Nobs, R2, YMean])
```

## Writing to a file

The output format is determined by the file extension:

```julia
modelsummary(m1, m2; file = "table.tex")   # LaTeX
modelsummary(m1, m2; file = "table.html")  # HTML
modelsummary(m1, m2; file = "table.typ")   # Typst
```

## Similar packages

- [RegressionTables.jl](https://github.com/jmboehm/RegressionTables.jl)

## License

MIT
