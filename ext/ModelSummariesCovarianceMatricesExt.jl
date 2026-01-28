module ModelSummariesCovarianceMatricesExt

using ModelSummaries
using CovarianceMatrices
using CovarianceMatrices: VcovSpec, AbstractAsymptoticVarianceEstimator
using StatsAPI
using StatsBase
using StatsModels

import StatsAPI: coef, stderror, dof_residual, responsename, coefnames, islinear, nobs, vcov
import Base: +

##############################################################################
##
## RegressionModelWithVcov - wrapper for model + vcov() syntax
##
## This type enables the model + vcov(estimator) syntax for attaching
## robust covariance estimators to regression models.
##
##############################################################################

"""
    struct RegressionModelWithVcov{M,T} <: RegressionModel

Wraps a regression model together with a covariance specification. Standard errors, `vcov`, and statistics
derived from them now draw from the attached specification, while all other queries are delegated to `model`.
Construct these via `rr + vcov(spec)`.

This type is only available when CovarianceMatrices.jl is loaded.

# Examples
```julia
using ModelSummaries, CovarianceMatrices, GLM, DataFrames

df = DataFrame(y = randn(100), x = randn(100))
model = lm(@formula(y ~ x), df)

# Create model with robust standard errors
model_hc3 = model + vcov(HC3())

# Use in modelsummary
modelsummary(model_hc3)
```
"""
struct RegressionModelWithVcov{M <: RegressionModel, T} <: RegressionModel
    model::M
    spec::VcovSpec{T}
    cache::Base.RefValue{Union{Nothing, AbstractMatrix}}
    function RegressionModelWithVcov(model::M, spec::VcovSpec{T}) where {
            M <: RegressionModel, T}
        new{M, T}(model, spec, Ref{Union{Nothing, AbstractMatrix}}(nothing))
    end
end

##############################################################################
##
## Base.:+ operators for model + vcov() syntax
##
##############################################################################

function +(rr::RegressionModel, spec::VcovSpec)
    RegressionModelWithVcov(rr, spec)
end

function +(rr::StatsModels.TableRegressionModel, spec::VcovSpec)
    RegressionModelWithVcov(rr, spec)
end

function +(spec::VcovSpec, rr::RegressionModel)
    rr + spec
end

function +(rr::RegressionModelWithVcov, spec::VcovSpec)
    RegressionModelWithVcov(rr.model, spec)
end

function +(spec::VcovSpec, rr::RegressionModelWithVcov)
    rr + spec
end

##############################################################################
##
## materialize_vcov - Compute variance-covariance matrix from VcovSpec
##
##############################################################################

# Dispatch on VcovSpec based on source type
_materialize_vcov(spec::VcovSpec{<:AbstractMatrix}, model) = spec.source

function _materialize_vcov(spec::VcovSpec{<:Function}, model)
    f = spec.source
    if applicable(f, model)
        return f(model)
    elseif applicable(f)
        return f()
    else
        throw(ArgumentError("Provided covariance function does not accept zero or one argument."))
    end
end

# For CovarianceMatrices estimators, unwrap and compute
function _materialize_vcov(spec::VcovSpec{<:AbstractAsymptoticVarianceEstimator}, model)
    return StatsBase.vcov(spec.source, model)
end

# Generic fallback for other types
function _materialize_vcov(spec::VcovSpec{T}, model) where {T}
    throw(ArgumentError("""
        No method to compute a covariance matrix for $(typeof(spec.source)).
        Define a method for _materialize_vcov or ensure the estimator type is supported.
        """))
end

function _validate_vcov_dimensions(model, Σ)
    ncoef = length(coef(model))
    m, n = size(Σ)

    # Check dimensions match number of coefficients
    if m != ncoef || n != ncoef
        throw(ArgumentError("Custom covariance matrix must be $(ncoef)×$(ncoef). Got size $(size(Σ))."))
    end

    # Check matrix is square (redundant but explicit)
    if m != n
        throw(ArgumentError("Covariance matrix must be square. Got size $(size(Σ))."))
    end

    # Check for symmetry (covariance matrices should be symmetric)
    # Use isapprox instead of issymmetric to handle floating-point rounding errors
    if !isapprox(Σ, transpose(Σ))
        @warn "Covariance matrix is not symmetric. This may indicate an error in computation."
    end
end

function _custom_vcov(rr::RegressionModelWithVcov)
    Σ = rr.cache[]
    if Σ === nothing
        Σ = _materialize_vcov(rr.spec, rr.model)
        if !(Σ isa AbstractMatrix)
            throw(ArgumentError("Custom covariance specification must return an AbstractMatrix. Got $(typeof(Σ))."))
        end
        _validate_vcov_dimensions(rr.model, Σ)
        rr.cache[] = Σ
    end
    Σ
end

function _custom_stderror(rr::RegressionModelWithVcov)
    Σ = _custom_vcov(rr)
    sqrt.(map(i -> Σ[i, i], axes(Σ, 1)))
end

##############################################################################
##
## StatsAPI method delegation for RegressionModelWithVcov
##
##############################################################################

coef(x::RegressionModelWithVcov) = coef(x.model)
stderror(x::RegressionModelWithVcov) = _custom_stderror(x)
dof_residual(x::RegressionModelWithVcov) = dof_residual(x.model)
responsename(x::RegressionModelWithVcov) = responsename(x.model)
coefnames(x::RegressionModelWithVcov) = coefnames(x.model)
islinear(x::RegressionModelWithVcov) = islinear(x.model)
nobs(x::RegressionModelWithVcov) = nobs(x.model)
vcov(x::RegressionModelWithVcov) = _custom_vcov(x)

##############################################################################
##
## ModelSummaries interface methods for RegressionModelWithVcov
##
##############################################################################

ModelSummaries._formula(x::RegressionModelWithVcov) = ModelSummaries._formula(x.model)
function ModelSummaries._responsename(x::RegressionModelWithVcov)
    ModelSummaries._responsename(x.model)
end
ModelSummaries._coefnames(x::RegressionModelWithVcov) = ModelSummaries._coefnames(x.model)
ModelSummaries._coef(x::RegressionModelWithVcov) = ModelSummaries._coef(x.model)
ModelSummaries._stderror(x::RegressionModelWithVcov) = _custom_stderror(x)
function ModelSummaries._dof_residual(x::RegressionModelWithVcov)
    ModelSummaries._dof_residual(x.model)
end
ModelSummaries._islinear(x::RegressionModelWithVcov) = ModelSummaries._islinear(x.model)
function ModelSummaries.can_standardize(x::RegressionModelWithVcov)
    ModelSummaries.can_standardize(x.model)
end
function ModelSummaries.RegressionType(x::RegressionModelWithVcov)
    ModelSummaries.RegressionType(x.model)
end
function ModelSummaries.default_regression_statistics(x::RegressionModelWithVcov)
    ModelSummaries.default_regression_statistics(x.model)
end
function ModelSummaries.other_stats(x::RegressionModelWithVcov, s::Symbol)
    ModelSummaries.other_stats(x.model, s)
end

# VcovType for RegressionModelWithVcov - detect type from the spec
function ModelSummaries.VcovType(x::RegressionModelWithVcov)
    source = x.spec.source
    if source isa AbstractMatrix
        return ModelSummaries.VcovType("Custom")
    elseif source isa Function
        return ModelSummaries.VcovType("Function")
    else
        # Try to get the name of the estimator type (e.g., HC3)
        # CovarianceMatrices.jl uses HR0, HR1, etc. Map them to HC0, HC1...
        s = string(typeof(source))
        # Strip module name if present
        if occursin(".", s)
            s = split(s, ".")[end]
        end

        if startswith(s, "HR") && length(s) == 3 && isdigit(s[3])
            return ModelSummaries.VcovType("HC" * s[3:end])
        end
        return ModelSummaries.VcovType(s)
    end
end

##############################################################################
##
## Display methods for RegressionModelWithVcov
##
##############################################################################

function Base.show(io::IO, m::RegressionModelWithVcov)
    print(io, "RegressionModelWithVcov(")
    print(io, typeof(m.model).name.name)
    print(io, ", vcov=", ModelSummaries.vcov_type_name(m.spec.source))
    print(io, ")")
end

function Base.show(io::IO, mime::MIME"text/plain", m::RegressionModelWithVcov)
    # Display the wrapped model
    show(io, mime, m.model)
    # Add vcov note
    vcov_name = ModelSummaries.vcov_type_name(m.spec.source)
    println(io)
    println(io, "Std. errors: ", vcov_name)
end

##############################################################################
##
## materialize_vcov for CovarianceMatrices estimators (for core ModelSummaries)
##
## This provides the extension point for ModelSummaries.materialize_vcov
## if it's still used elsewhere in the codebase.
##
##############################################################################

"""
    ModelSummaries.materialize_vcov(estimator, model)

Compute the variance-covariance matrix for a regression model using a CovarianceMatrices.jl estimator.

This method enables integration between ModelSummaries.jl and CovarianceMatrices.jl, allowing
users to specify robust variance estimators (HC0-HC5, HAC, cluster-robust CR0-CR3, etc.) when
creating regression tables.

# Examples
```julia
using ModelSummaries, CovarianceMatrices, GLM, DataFrames

# Fit a regression model
df = DataFrame(y = randn(100), x1 = randn(100), x2 = randn(100), id = rand(1:10, 100))
model = lm(@formula(y ~ x1 + x2), df)

# Create table with HC3 robust standard errors
modelsummary(model + vcov(HC3()))

# Or with HAC standard errors
modelsummary(model + vcov(HAC(Bartlett, 5)))

# Or with cluster-robust standard errors (CR0, CR1, CR2, CR3)
modelsummary(model + vcov(CR0(:id)))
```
"""
function ModelSummaries.materialize_vcov(
        estimator::AbstractAsymptoticVarianceEstimator,
        model::StatsAPI.RegressionModel
)
    return StatsBase.vcov(estimator, model)
end

##############################################################################
##
## vcov_type_name methods for CovarianceMatrices estimators
##
##############################################################################

# HC/HR estimators - show as "HC" (more common notation)
# In CovarianceMatrices.jl, HC0-HC3 are type aliases for HR0-HR3
ModelSummaries.vcov_type_name(::CovarianceMatrices.HR0) = "HC0"
ModelSummaries.vcov_type_name(::CovarianceMatrices.HR1) = "HC1"
ModelSummaries.vcov_type_name(::CovarianceMatrices.HR2) = "HC2"
ModelSummaries.vcov_type_name(::CovarianceMatrices.HR3) = "HC3"

# HAC estimators with bandwidth
# Fixed bandwidth: Bartlett(5) -> "Bartlett(5)"
# Auto bandwidth: Bartlett(NeweyWest) -> "Bartlett(auto), bw: 4.27"

# Helper to get clean kernel name (BartlettKernel -> Bartlett)
function _hac_kernel_name(v::CovarianceMatrices.HAC)
    typename = string(typeof(v).name.name)
    return replace(typename, "Kernel" => "")
end

function ModelSummaries.vcov_type_name(v::CovarianceMatrices.HAC{<:CovarianceMatrices.Fixed})
    typename = _hac_kernel_name(v)
    bw_val = v.bw[1]
    # Show as integer if it's a whole number
    if bw_val == floor(bw_val)
        return string(typename, "(", Int(bw_val), ")")
    else
        return string(typename, "(", round(bw_val, digits = 2), ")")
    end
end

function ModelSummaries.vcov_type_name(v::CovarianceMatrices.HAC)
    typename = _hac_kernel_name(v)
    bw_val = v.bw[1]
    if bw_val == 0.0
        # Bandwidth not yet computed
        return string(typename, "(auto)")
    else
        return string(typename, "(auto), bw: ", round(bw_val, digits = 2))
    end
end

##############################################################################
##
## F-statistic for RegressionModelWithVcov (robust F-test)
##
## When using robust vcov, we compute F-statistic using Wald test
##
##############################################################################

using Distributions: FDist, ccdf

# Vcov-aware F-statistic using Wald test
function _fstat_robust(model::RegressionModelWithVcov)
    # Get custom vcov and coefficients
    Σ = vcov(model)  # This will use the custom vcov
    β = coef(model)
    n = nobs(model)
    p = length(β) - 1  # Number of predictors (excluding intercept)

    if p == 0 || n <= p + 1
        return ModelSummaries.FStat(nothing)
    end

    # For overall F-test, test that all non-intercept coefficients are zero
    # Use Wald statistic: W = β_r' Σ_r^{-1} β_r where β_r are non-intercept coefficients
    # F = W / p
    β_restricted = β[2:end]  # Exclude intercept
    Σ_restricted = Σ[2:end, 2:end]  # Corresponding vcov sub-matrix

    # Compute Wald statistic
    try
        W = β_restricted' * inv(Σ_restricted) * β_restricted
        f_stat = W / p
        return ModelSummaries.FStat(f_stat)
    catch e
        # If vcov matrix is singular or other error, return nothing
        @warn "Failed to compute robust F-statistic" exception=e
        return ModelSummaries.FStat(nothing)
    end
end

function _fstatpval_robust(model::RegressionModelWithVcov)
    f_obj = _fstat_robust(model)
    if f_obj.val === nothing
        return ModelSummaries.FStatPValue(nothing)
    end

    β = coef(model)
    n = nobs(model)
    p = length(β) - 1

    # Wald test: under null hypothesis, F ~ F(p, ∞)
    # For finite samples with robust vcov, we use F(p, n-k) distribution
    # where k is the total number of parameters
    fdist = FDist(p, n - length(β))
    pval = ccdf(fdist, f_obj.val)

    return ModelSummaries.FStatPValue(pval)
end

# Hook for RegressionModelWithVcov
ModelSummaries.FStat(model::RegressionModelWithVcov) = _fstat_robust(model)
ModelSummaries.FStatPValue(model::RegressionModelWithVcov) = _fstatpval_robust(model)

end
