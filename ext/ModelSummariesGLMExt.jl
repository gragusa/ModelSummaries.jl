module ModelSummariesGLMExt

using GLM: GLM, GeneralizedLinearModel, LinearModel
using ModelSummaries: ModelSummaries, AdjR2, FStat, FStatIV, FStatIVPValue, FStatPValue,
                      Nobs, R2, R2McFadden, R2Within, RegressionType, VcovType
using Distributions: FDist, Normal, TDist, ccdf
using Statistics: std
using StatsAPI: deviance, dof, dof_residual, modelmatrix, nulldeviance, response
using StatsModels: StatsModels, hasintercept

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

function ModelSummaries.VcovType(x::StatsModels.TableRegressionModel{<:GLM.LinPredModel})
    VcovType(x.model)
end
ModelSummaries.VcovType(::LinearModel) = VcovType("IID")
# GLM's `vcov` is the inverse of the estimated information matrix, scaled by the dispersion
# for families that have one.
ModelSummaries.VcovType(::GeneralizedLinearModel) = VcovType("Information-based")

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

# Degrees of freedom of the overall F-test of every coefficient except the intercept against
# GLM's null model (intercept only, or no predictor when the model has no intercept).
# `dof(::LinearModel)` counts σ as well as the estimated coefficients.
function _ftest_dof(model::LinearModel)
    (dof(model) - 1 - hasintercept(model), dof_residual(model))
end

function ModelSummaries.applies(::Type{<:Union{FStat, FStatPValue}}, model::LinearModel)
    df1, df2 = _ftest_dof(model)
    df1 > 0 && df2 > 0
end

function ModelSummaries.FStat(model::LinearModel)
    df1, df2 = _ftest_dof(model)
    rss = deviance(model)
    FStat(((nulldeviance(model) - rss) / df1) / (rss / df2))
end

function ModelSummaries.FStatPValue(model::LinearModel)
    FStatPValue(ccdf(FDist(_ftest_dof(model)...), ModelSummaries.FStat(model).val))
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
