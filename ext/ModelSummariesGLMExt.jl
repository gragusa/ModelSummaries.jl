module ModelSummariesGLMExt

using GLM
using ModelSummaries
using StatsModels
using Statistics

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


end
