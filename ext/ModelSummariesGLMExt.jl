module ModelSummariesGLMExt

using GLM
using ModelSummaries
using StatsModels
using Statistics
using Distributions
using LinearAlgebra

ModelSummaries.default_regression_statistics(rr::LinearModel) = [Nobs, R2]
function ModelSummaries.default_regression_statistics(rr::StatsModels.TableRegressionModel{T}) where {T <:
                                                                                                      GLM.AbstractGLM}
    [Nobs, R2McFadden]
end

function ModelSummaries.RegressionType(x::StatsModels.TableRegressionModel{T}) where {T <:
                                                                                      GLM.AbstractGLM}
    RegressionType(x.model)
end
function ModelSummaries.RegressionType(x::StatsModels.TableRegressionModel{T}) where {T <:
                                                                                      LinearModel}
    RegressionType(x.model)
end

# k is which coefficient or standard error to standardize
function ModelSummaries.standardize_coef_values(
        x::StatsModels.TableRegressionModel{<:GLM.LinPredModel}, val, k)
    ModelSummaries.standardize_coef_values(std(modelmatrix(x)[:, k]), std(response(x)), val)
end

function ModelSummaries.can_standardize(x::StatsModels.TableRegressionModel{<:GLM.LinPredModel})
    true
end

ModelSummaries.RegressionType(x::LinearModel) = RegressionType(Normal())
ModelSummaries.RegressionType(x::GLM.LmResp) = RegressionType(Normal())
ModelSummaries.RegressionType(x::GeneralizedLinearModel) = RegressionType(x.rr)
ModelSummaries.RegressionType(x::GLM.GlmResp{Y, D, L}) where {Y, D, L} = RegressionType(D)

function ModelSummaries.applies(S, model::StatsModels.TableRegressionModel)
    ModelSummaries.applies(S, model.model)
end

# Statistics that GLM does not define for these model types
ModelSummaries.applies(::Type{<:Union{R2, AdjR2}}, ::GeneralizedLinearModel) = false
function ModelSummaries.applies(::Type{<:Union{FStat, FStatPValue}}, ::GeneralizedLinearModel)
    false
end
function ModelSummaries.applies(
        ::Type{<:Union{FStatIV, FStatIVPValue, R2Within}}, ::GLM.LinPredModel)
    false
end

# The overall F-test needs at least one predictor and positive residual degrees of freedom.
function ModelSummaries.applies(::Type{<:Union{FStat, FStatPValue}}, model::LinearModel)
    p = dof(model) - 1
    p > 0 && nobs(model) > p + 1
end

# F-statistic for LinearModel
function ModelSummaries.FStat(model::LinearModel)
    # F = (R² / p) / ((1 - R²) / (n - p - 1))
    # where p = number of predictors (excluding intercept)
    r2_val = r2(model)
    n = nobs(model)
    p = dof(model) - 1  # dof includes intercept, so subtract 1 for number of predictors

    f_stat = (r2_val / p) / ((1 - r2_val) / (n - p - 1))
    return FStat(f_stat)
end

function ModelSummaries.FStatPValue(model::LinearModel)
    f_obj = ModelSummaries.FStat(model)
    n = nobs(model)
    p = dof(model) - 1

    # F-distribution with p and (n - p - 1) degrees of freedom
    fdist = FDist(p, n - p - 1)
    pval = ccdf(fdist, f_obj.val)

    return FStatPValue(pval)
end

# F-statistic for TableRegressionModel wrapping LinearModel
function ModelSummaries.FStat(model::StatsModels.TableRegressionModel{<:LinearModel})
    ModelSummaries.FStat(model.model)
end
function ModelSummaries.FStatPValue(model::StatsModels.TableRegressionModel{<:LinearModel})
    ModelSummaries.FStatPValue(model.model)
end

# Distribution behind GLM's coeftable p-values: t for linear models, Normal for every GLM
# (including the Normal family).
function ModelSummaries.reference_distribution(x::StatsModels.TableRegressionModel)
    ModelSummaries.reference_distribution(x.model)
end
ModelSummaries.reference_distribution(x::LinearModel) = TDist(dof_residual(x))
ModelSummaries.reference_distribution(::GeneralizedLinearModel) = Normal()

end
