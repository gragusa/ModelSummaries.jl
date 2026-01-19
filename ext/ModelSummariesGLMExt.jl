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

# Note: F-statistic for RegressionModelWithVcov is handled in ModelSummariesCovarianceMatricesExt
# when CovarianceMatrices is loaded. The robust F-statistic methods are defined there.

end
