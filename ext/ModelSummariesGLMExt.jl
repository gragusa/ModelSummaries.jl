module ModelSummariesGLMExt

using GLM
using ModelSummaries
using StatsModels
using Statistics
using Distributions
using LinearAlgebra

ModelSummaries.default_regression_statistics(rr::LinearModel) = [Nobs, R2]
ModelSummaries.default_regression_statistics(rr::StatsModels.TableRegressionModel{T}) where {T<:GLM.AbstractGLM} = [Nobs, R2McFadden]

ModelSummaries.RegressionType(x::StatsModels.TableRegressionModel{T}) where {T<:GLM.AbstractGLM} = RegressionType(x.model)
ModelSummaries.RegressionType(x::StatsModels.TableRegressionModel{T}) where {T<:LinearModel} = RegressionType(x.model)

# k is which coefficient or standard error to standardize
ModelSummaries.standardize_coef_values(x::StatsModels.TableRegressionModel, val, k) =
    ModelSummaries.standardize_coef_values(std(modelmatrix(x)[:, k]), std(response(x)), val)

ModelSummaries.can_standardize(x::StatsModels.TableRegressionModel) = true

ModelSummaries.RegressionType(x::LinearModel) = RegressionType(Normal())
ModelSummaries.RegressionType(x::GLM.LmResp) = RegressionType(Normal())
ModelSummaries.RegressionType(x::GeneralizedLinearModel) = RegressionType(x.rr)
ModelSummaries.RegressionType(x::GLM.GlmResp{Y, D, L}) where {Y, D, L} = RegressionType(D)

# F-statistic for LinearModel
function ModelSummaries.FStat(model::LinearModel)
    # F = (R² / p) / ((1 - R²) / (n - p - 1))
    # where p = number of predictors (excluding intercept)
    r2_val = r2(model)
    n = nobs(model)
    p = dof(model) - 1  # dof includes intercept, so subtract 1 for number of predictors

    if p == 0 || n <= p + 1
        return FStat(nothing)
    end

    f_stat = (r2_val / p) / ((1 - r2_val) / (n - p - 1))
    return FStat(f_stat)
end

function ModelSummaries.FStatPValue(model::LinearModel)
    f_obj = ModelSummaries.FStat(model)
    if f_obj.val === nothing
        return FStatPValue(nothing)
    end

    n = nobs(model)
    p = dof(model) - 1

    # F-distribution with p and (n - p - 1) degrees of freedom
    fdist = FDist(p, n - p - 1)
    pval = ccdf(fdist, f_obj.val)

    return FStatPValue(pval)
end

# F-statistic for TableRegressionModel wrapping LinearModel
ModelSummaries.FStat(model::StatsModels.TableRegressionModel{<:LinearModel}) =
    ModelSummaries.FStat(model.model)
ModelSummaries.FStatPValue(model::StatsModels.TableRegressionModel{<:LinearModel}) =
    ModelSummaries.FStatPValue(model.model)

# Vcov-aware F-statistic using Wald test
# When a RegressionModelWithVcov is used, compute F-statistic using robust vcov
# This works for both LinearModel and TableRegressionModel{LinearModel}
function _fstat_robust(model::ModelSummaries.RegressionModelWithVcov)
    # Get the underlying base model (unwrap TableRegressionModel if needed)
    base_model = model.model
    if base_model isa StatsModels.TableRegressionModel
        inner_model = base_model.model
        if !(inner_model isa LinearModel)
            return FStat(nothing)  # Only support LinearModel
        end
    elseif base_model isa LinearModel
        inner_model = base_model
    else
        return FStat(nothing)
    end

    # Get custom vcov and coefficients
    Σ = vcov(model)  # This will use the custom vcov
    β = coef(model)
    n = nobs(model)
    p = length(β) - 1  # Number of predictors (excluding intercept)

    if p == 0 || n <= p + 1
        return FStat(nothing)
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
        return FStat(f_stat)
    catch e
        # If vcov matrix is singular or other error, return nothing
        @warn "Failed to compute robust F-statistic" exception=e
        return FStat(nothing)
    end
end

function _fstatpval_robust(model::ModelSummaries.RegressionModelWithVcov)
    f_obj = _fstat_robust(model)
    if f_obj.val === nothing
        return FStatPValue(nothing)
    end

    β = coef(model)
    n = nobs(model)
    p = length(β) - 1

    # Wald test: under null hypothesis, F ~ F(p, ∞)
    # For finite samples with robust vcov, we use F(p, n-k) distribution
    # where k is the total number of parameters
    fdist = FDist(p, n - length(β))
    pval = ccdf(fdist, f_obj.val)

    return FStatPValue(pval)
end

# Hook for any RegressionModelWithVcov
ModelSummaries.FStat(model::ModelSummaries.RegressionModelWithVcov) = _fstat_robust(model)
ModelSummaries.FStatPValue(model::ModelSummaries.RegressionModelWithVcov) = _fstatpval_robust(model)

end
