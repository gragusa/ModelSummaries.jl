module ModelSummariesFixedEffectModelsExt

using FixedEffectModels
using ModelSummaries
using Distributions
using StatsModels
using StatsAPI: coeftable, dof_residual

ModelSummaries.FStat(x::FixedEffectModel) = FStat(x.F)
ModelSummaries.FStatPValue(x::FixedEffectModel) = FStatPValue(x.p)

ModelSummaries.FStatIV(x::FixedEffectModel) = FStatIV(x.F_kp)
ModelSummaries.FStatIVPValue(x::FixedEffectModel) = FStatIVPValue(x.p_kp)
ModelSummaries.R2Within(x::FixedEffectModel) = R2Within(x.r2_within)

function ModelSummaries.applies(::Type{<:Union{FStatIV, FStatIVPValue}}, x::FixedEffectModel)
    has_iv(x)
end
ModelSummaries.applies(::Type{R2Within}, x::FixedEffectModel) = has_fe(x)

ModelSummaries.RegressionType(x::FixedEffectModel) = RegressionType(Normal(), has_iv(x))

# Vcov.jl scales `robust()` by n/(n-k) and `cluster()` by (n-1)/(n-k) * G/(G-1).
ModelSummaries.VcovType(x::FixedEffectModel) = VcovType(_vcov_label(x.vcov_type))
_vcov_label(::FixedEffectModels.Vcov.SimpleCovariance) = "IID"
_vcov_label(::FixedEffectModels.Vcov.RobustCovariance) = "HC1"
_vcov_label(::FixedEffectModels.Vcov.ClusterCovariance) = "CR1"
function _vcov_label(v)
    throw(ArgumentError("no `VcovType` label for the FixedEffectModels covariance estimator \
        $(typeof(v)); add a `_vcov_label` method in ModelSummariesFixedEffectModelsExt"))
end

# FixedEffectModels' coeftable leaves `teststatcol` unset.
function ModelSummaries.inference_coeftable(x::FixedEffectModel)
    ModelSummaries.with_teststatcol(coeftable(x), "t-stat")
end
ModelSummaries.reference_distribution(x::FixedEffectModel) = TDist(dof_residual(x))

function ModelSummaries.get_coefname(x::StatsModels.FunctionTerm{typeof(FixedEffectModels.fe)})
    ModelSummaries.CoefName(string(x.exorig.args[end]))
end
function ModelSummaries.get_coefname(x::FixedEffectModels.FixedEffectTerm)
    ModelSummaries.CoefName(string(x.x))
end

function ModelSummaries.other_stats(rr::FixedEffectModel, s::Symbol)
    if s == :fe
        ModelSummaries.fixed_effect_entries(rr.formula.rhs, has_fe)
    elseif s == :clusters && rr.nclusters !== nothing
        ModelSummaries.cluster_entries(keys(rr.nclusters), values(rr.nclusters))
    else
        nothing
    end
end

function ModelSummaries.default_regression_statistics(rr::FixedEffectModel)
    if has_iv(rr)
        [Nobs, R2, R2Within, FStatIV]
    elseif has_fe(rr)
        [Nobs, R2, R2Within]
    else
        [Nobs, R2]
    end
end

end
