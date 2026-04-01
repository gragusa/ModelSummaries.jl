abstract type AbstractRegressionData end

Base.broadcastable(x::AbstractRegressionData) = Ref(x)

"""
AbstractRegressionStatistic encapsulates all regression statistics
(e.g., number of observations, ``R^2``, etc.). In most cases, the individual regression
packages provide functions that access these, generally from the [StatsAPI.jl](https://github.com/JuliaStats/StatsAPI.jl)
package. If the function does not exist in the regression package, it is typically added in
the extension to this package. Since some statistics are not relevant for all regressions,
the value of the statistic is wrapped in a `Union` with `Nothing` to indicate that the
value is not available.

To define a new regression statistic, three things are needed:
1. A new type that is a subtype of `AbstractRegressionStatistic`
2. A constructor that takes a `RegressionModel` and returns the new type (or `nothing` if the statistic is not available)
3. A `label` function: `label(::Type{YourStat}) = "Your Label"`

It is also helpful to maintain consistency by defining the value as `val` within the struct.

For example:
```julia
struct YMean <: ModelSummaries.AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
YMean(x::RegressionModel) = try
    YMean(mean(x.model.rr.y))
catch
    YMean(nothing)
end
ModelSummaries.label(::Type{YMean}) = "Mean of Y"
```
"""
abstract type AbstractRegressionStatistic <: AbstractRegressionData end

"""
    abstract type AbstractR2 <: AbstractRegressionStatistic end

Parent type for all ``R^2`` statistics.
"""
abstract type AbstractR2 <: AbstractRegressionStatistic end

"""
`Nobs` is the number of observations in the regression.
"""
struct Nobs <: AbstractRegressionStatistic
    val::Union{Int, Nothing}
end
Nobs(x::RegressionModel) =
    try
        Nobs(nobs(x))
    catch
        Nobs(nothing)
    end

label(::Type{Nobs}) = "N"

"""
`R2` is the ``R^2`` of the regression.
"""
struct R2 <: AbstractR2
    val::Union{Float64, Nothing}
end
R2(x::RegressionModel) =
    try
        R2(r2(x))
    catch
        R2(nothing)
    end

label(::Type{R2}) = Concat("R", Superscript("2"))

"""
`R2McFadden` is the McFadden ``R^2`` (Pseudo-``R^2``).
"""
struct R2McFadden <: AbstractR2
    val::Union{Float64, Nothing}
end
R2McFadden(x::RegressionModel) =
    try
        R2McFadden(r2(x, :McFadden))
    catch
        R2McFadden(nothing)
    end

label(::Type{R2McFadden}) = Concat("Pseudo R", Superscript("2"))

const PseudoR2 = R2McFadden

"""
`R2CoxSnell` is the Cox-Snell ``R^2``.
"""
struct R2CoxSnell <: AbstractR2
    val::Union{Float64, Nothing}
end
R2CoxSnell(x::RegressionModel) =
    try
        R2CoxSnell(r2(x, :CoxSnell))
    catch
        R2CoxSnell(nothing)
    end

label(::Type{R2CoxSnell}) = Concat("Cox-Snell R", Superscript("2"))

"""
`R2Nagelkerke` is the Nagelkerke ``R^2``.
"""
struct R2Nagelkerke <: AbstractR2
    val::Union{Float64, Nothing}
end
R2Nagelkerke(x::RegressionModel) =
    try
        R2Nagelkerke(r2(x, :Nagelkerke))
    catch
        R2Nagelkerke(nothing)
    end

label(::Type{R2Nagelkerke}) = Concat("Nagelkerke R", Superscript("2"))

"""
`R2Deviance` is the Deviance ``R^2``.
"""
struct R2Deviance <: AbstractR2
    val::Union{Float64, Nothing}
end
R2Deviance(x::RegressionModel) =
    try
        R2Deviance(r2(x, :devianceratio))
    catch
        R2Deviance(nothing)
    end

label(::Type{R2Deviance}) = Concat("Deviance R", Superscript("2"))

"""
`AdjR2` is the Adjusted ``R^2``.
"""
struct AdjR2 <: AbstractR2
    val::Union{Float64, Nothing}
end
AdjR2(x::RegressionModel) =
    try
        AdjR2(adjr2(x))
    catch
        AdjR2(nothing)
    end

label(::Type{AdjR2}) = Concat("Adjusted R", Superscript("2"))

"""
`AdjR2McFadden` is the McFadden Adjusted ``R^2`` (Pseudo Adjusted ``R^2``).
"""
struct AdjR2McFadden <: AbstractR2
    val::Union{Float64, Nothing}
end
AdjR2McFadden(x::RegressionModel) =
    try
        AdjR2McFadden(adjr2(x, :McFadden))
    catch
        AdjR2McFadden(nothing)
    end

label(::Type{AdjR2McFadden}) = Concat("Pseudo Adjusted R", Superscript("2"))

const AdjPseudoR2 = AdjR2McFadden

"""
`AdjR2Deviance` is the Deviance Adjusted ``R^2``.
"""
struct AdjR2Deviance <: AbstractR2
    val::Union{Float64, Nothing}
end
AdjR2Deviance(x::RegressionModel) =
    try
        AdjR2Deviance(adjr2(x, :devianceratio))
    catch
        AdjR2Deviance(nothing)
    end

label(::Type{AdjR2Deviance}) = Concat("Deviance Adjusted R", Superscript("2"))

"""
`DOF` is the remaining degrees of freedom in the regression.
"""
struct DOF <: AbstractRegressionStatistic
    val::Union{Int, Nothing}
end
DOF(x::RegressionModel) =
    try
        DOF(dof_residual(x))
    catch
        DOF(nothing)
    end

label(::Type{DOF}) = "Degrees of Freedom"

"""
`LogLikelihood` is the log likelihood of the regression.
"""
struct LogLikelihood <: AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
LogLikelihood(x::RegressionModel) =
    try
        LogLikelihood(loglikelihood(x))
    catch
        LogLikelihood(nothing)
    end

label(::Type{LogLikelihood}) = "Log Likelihood"

"""
`AIC` is the Akaike Information Criterion.
"""
struct AIC <: AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
AIC(x::RegressionModel) =
    try
        AIC(aic(x))
    catch
        AIC(nothing)
    end

label(::Type{AIC}) = "AIC"

"""
`AICC` is the Corrected Akaike Information Criterion.
"""
struct AICC <: AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
AICC(x::RegressionModel) =
    try
        AICC(aicc(x))
    catch
        AICC(nothing)
    end

label(::Type{AICC}) = "AICC"

"""
`BIC` is the Bayesian Information Criterion.
"""
struct BIC <: AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
BIC(x::RegressionModel) =
    try
        BIC(bic(x))
    catch
        BIC(nothing)
    end

label(::Type{BIC}) = "BIC"

"""
`FStat` is the F-statistic of the regression.
"""
struct FStat <: AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
FStat(r::RegressionModel) = FStat(nothing)

label(::Type{FStat}) = "F"

"""
`FStatPValue` is the p-value of the F-statistic.
"""
struct FStatPValue <: AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
FStatPValue(r::RegressionModel) = FStatPValue(nothing)

label(::Type{FStatPValue}) = label(FStat) * "-test p value"

"""
`FStatIV` is the first-stage F-statistic of an IV regression.
"""
struct FStatIV <: AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
FStatIV(r::RegressionModel) = FStatIV(nothing)

label(::Type{FStatIV}) = "First-stage " * label(FStat) * " statistic"

"""
`FStatIVPValue` is the p-value of the first-stage F-statistic.
"""
struct FStatIVPValue <: AbstractRegressionStatistic
    val::Union{Float64, Nothing}
end
FStatIVPValue(r::RegressionModel) = FStatIVPValue(nothing)

label(::Type{FStatIVPValue}) = "First-stage p value"

"""
`R2Within` is the within R-squared of a fixed effects regression.
"""
struct R2Within <: AbstractR2
    val::Union{Float64, Nothing}
end
R2Within(r::RegressionModel) = R2Within(nothing)

label(::Type{R2Within}) = Concat("Within-R", Superscript("2"))

"""
`VcovType` describes the type of covariance matrix estimator used.
"""
struct VcovType <: AbstractRegressionStatistic
    val::Union{String, Nothing}
end

label(::Type{VcovType}) = "Std. Error"

"""
    struct Spacer <: AbstractRegressionStatistic end

A spacer statistic that produces an empty row in the table.
"""
struct Spacer <: AbstractRegressionStatistic end
Spacer(x::RegressionModel) = Spacer()
value(::Spacer) = nothing
label(::Type{Spacer}) = ""

value(s::AbstractRegressionStatistic) = s.val

Base.show(io::IO, s::AbstractRegressionStatistic) = show(io, value(s))
Base.print(io::IO, s::AbstractRegressionStatistic) = print(io, value(s))

"""
    abstract type AbstractUnderStatistic end

The abstract type for statistics that are below or next to the coefficients
(e.g., standard errors, t-statistics, confidence intervals, etc.).
"""
abstract type AbstractUnderStatistic <: AbstractRegressionData end

"""
    struct TStat <: AbstractUnderStatistic
        val::Float64
    end

The t-statistic of a coefficient.
"""
struct TStat <: AbstractUnderStatistic
    val::Float64
end
TStat(rr::RegressionModel, k::Int; vargs...) = TStat(_coef(rr)[k] / _stderror(rr)[k])

"""
    struct StdError <: AbstractUnderStatistic
        val::Float64
    end

The standard error of a coefficient.
"""
struct StdError <: AbstractUnderStatistic
    val::Float64
end
function StdError(rr::RegressionModel, k::Int; standardize = false, vargs...)
    if standardize
        StdError(standardize_coef_values(rr, _stderror(rr)[k], k))
    else
        StdError(_stderror(rr)[k])
    end
end

"""
    struct ConfInt <: AbstractUnderStatistic
        val::Tuple{Float64, Float64}
    end

The confidence interval of a coefficient.
"""
struct ConfInt <: AbstractUnderStatistic
    val::Tuple{Float64, Float64}
end

function ConfInt(rr::RegressionModel, k::Int; level = 0.95, standardize = false, vargs...)
    @assert 0 < level < 1 "Confidence level must be between 0 and 1"
    c_int = confint(rr; level)[k, :] |> Tuple
    if standardize
        c_int = standardize_coef_values.(Ref(rr), c_int, k)
    end
    ConfInt(c_int)
end

value(x::AbstractUnderStatistic) = x.val

"""
    struct CoefValue
        val::Float64
        pvalue::Float64
    end

The value of a coefficient and its p-value.
"""
struct CoefValue <: AbstractRegressionData
    val::Float64
    pvalue::Float64
end
function CoefValue(rr::RegressionModel, k::Int; standardize = false, vargs...)
    val = _coef(rr)[k]
    p = _pvalue(rr)[k]
    if standardize
        val = standardize_coef_values(rr, val, k)
    end
    CoefValue(val, p)
end
value(x::CoefValue) = x.val
value_pvalue(x::CoefValue) = x.pvalue
value_pvalue(x::Missing) = missing
value_pvalue(x::Nothing) = nothing

"""
    struct RegressionType{T}
        val::T
        is_iv::Bool
    end

The type of the regression.
"""
struct RegressionType{T} <: AbstractRegressionData
    val::T
    is_iv::Bool
    function RegressionType(x::T, is_iv::Bool = false) where {T <: UnivariateDistribution}
        new{T}(x, is_iv)
    end
    RegressionType(x::T, is_iv::Bool = false) where {T <: AbstractString} = new{T}(x, is_iv)
end
function RegressionType(x::Type{D}, is_iv::Bool = false) where {D <: UnivariateDistribution}
    RegressionType(Base.typename(D).wrapper(), is_iv)
end
value(x::RegressionType) = x.val

label(::Type{<:RegressionType}) = "Estimator"

"""
    struct HasControls
        val::Bool
    end

Indicates whether the regression has coefficients left out of the table.
"""
struct HasControls <: AbstractRegressionData
    val::Bool
end
value(x::HasControls) = x.val

label(::Type{HasControls}) = "Controls"

"""
    struct RegressionNumbers
        val::Int
    end

Used to define which column number the regression is in.
"""
struct RegressionNumbers <: AbstractRegressionData
    val::Int
end
value(x::RegressionNumbers) = x.val

label(::Type{RegressionNumbers}) = ""

value(x) = missing
value(x::String) = x

"""
    struct FixedEffectValue
        val::Bool
    end

A simple store of true/false for whether a fixed effect is used in the regression.
"""
struct FixedEffectValue <: AbstractRegressionData
    val::Bool
end

value(x::FixedEffectValue) = x.val

"""
    struct RandomEffectValue
        val::Real
    end

A simple store of the random effect value (typically the standard deviation).
"""
struct RandomEffectValue <: AbstractRegressionData
    val::Real
end

value(x::RandomEffectValue) = x.val

"""
    struct ClusterValue
        val::Int
    end

A simple store of the number of clusters used in the regression.
"""
struct ClusterValue <: AbstractRegressionData
    val::Int
end

value(x::ClusterValue) = x.val

"""
    struct FirstStageValue
        val::Union{Float64, Nothing}
    end

Store first-stage F-statistic value for IV models.
"""
struct FirstStageValue <: AbstractRegressionData
    val::Union{Float64, Nothing}
end

value(x::FirstStageValue) = x.val

fill_missing(x::AbstractRegressionData) = missing
fill_missing(x::FixedEffectValue) = FixedEffectValue(false)
fill_missing(x::FirstStageValue) = FirstStageValue(nothing)
