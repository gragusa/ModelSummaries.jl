module ModelSummariesRegressExt

using Regress: Regress, IVEstimator, OLSEstimator, has_fe
using ModelSummaries: ModelSummaries, FStat, FStatIV, FStatIVPValue, FStatPValue, Nobs, R2,
                      R2Within, RegressionType, VcovType
using Distributions: Normal, TDist
using StatsModels: StatsModels
using StatsAPI: coeftable, dof_residual

##############################################################################
## Statistics for OLSEstimator and IVEstimator
##############################################################################

# F-statistic
ModelSummaries.FStat(x::OLSEstimator) = FStat(x.F)
ModelSummaries.FStat(x::IVEstimator) = FStat(x.F)
ModelSummaries.FStatPValue(x::OLSEstimator) = FStatPValue(x.p)
ModelSummaries.FStatPValue(x::IVEstimator) = FStatPValue(x.p)

# First-stage F-statistic (IV only)
ModelSummaries.FStatIV(x::IVEstimator) = FStatIV(x.F_kp)
ModelSummaries.FStatIVPValue(x::IVEstimator) = FStatIVPValue(x.p_kp)
function ModelSummaries.applies(::Type{<:Union{FStatIV, FStatIVPValue}}, ::OLSEstimator)
    false
end

# Within R²
ModelSummaries.R2Within(x::Union{OLSEstimator, IVEstimator}) = R2Within(x.r2_within)
function ModelSummaries.applies(::Type{R2Within}, x::Union{OLSEstimator, IVEstimator})
    has_fe(x)
end

# The estimator behind `stderror`: Regress's default, or the one attached by `+ vcov(...)`.
function ModelSummaries.VcovType(x::Union{OLSEstimator, IVEstimator})
    VcovType(ModelSummaries.vcov_type_name(x.vcov_estimator, x))
end

# Regress's coeftable leaves `teststatcol` unset.
function ModelSummaries.inference_coeftable(x::Union{OLSEstimator, IVEstimator})
    ModelSummaries.with_teststatcol(coeftable(x), "t-stat")
end
function ModelSummaries.reference_distribution(x::Union{OLSEstimator, IVEstimator})
    TDist(dof_residual(x))
end

# Regression Type
ModelSummaries.RegressionType(x::OLSEstimator) = RegressionType(Normal(), false)
ModelSummaries.RegressionType(x::IVEstimator) = RegressionType(Normal(), true)

##############################################################################
## Coefficient Names (for FE terms in formula)
##############################################################################

# Handle fe() terms from Regress formula
function ModelSummaries.get_coefname(x::StatsModels.FunctionTerm{typeof(Regress.fe)})
    ModelSummaries.CoefName(string(x.exorig.args[end]))
end

##############################################################################
## Fixed Effects and Clusters for OLSEstimator
##############################################################################

function ModelSummaries.other_stats(rr::OLSEstimator, s::Symbol)
    if s == :fe
        has_fe(rr) || return nothing
        ModelSummaries.fixed_effect_entries(rr.formula.rhs, has_fe)
    elseif s == :clusters
        # Check if cluster variables are stored
        hasfield(typeof(rr.fes), :clusters) && !isempty(rr.fes.clusters) || return nothing
        clusters = rr.fes.clusters
        ModelSummaries.cluster_entries(keys(clusters), length.(unique.(values(clusters))))
    elseif s == :first_stage
        # OLS models have no first stage
        nothing
    else
        nothing
    end
end

##############################################################################
## Fixed Effects, Clusters, and First Stage for IVEstimator
##############################################################################

function ModelSummaries.other_stats(rr::IVEstimator, s::Symbol)
    if s == :fe
        has_fe(rr) || return nothing
        ModelSummaries.fixed_effect_entries(rr.formula.rhs, has_fe)
    elseif s == :clusters
        isnothing(rr.postestimation) && return nothing
        cluster_vars = rr.postestimation.cluster_vars
        isempty(cluster_vars) && return nothing
        ModelSummaries.cluster_entries(keys(cluster_vars),
            length.(unique.(values(cluster_vars))))
    elseif s == :first_stage
        # Return first-stage F-statistic (Kleibergen-Paap) as a section
        isnothing(rr.F_kp) && return nothing
        [
            ModelSummaries.FirstStageCoefName("F-statistic") =>
            ModelSummaries.FirstStageValue(rr.F_kp)
        ]
    else
        nothing
    end
end

##############################################################################
## Default Statistics
##############################################################################

function ModelSummaries.default_regression_statistics(rr::OLSEstimator)
    has_fe(rr) ? [Nobs, R2, R2Within] : [Nobs, R2]
end

function ModelSummaries.default_regression_statistics(rr::IVEstimator)
    if has_fe(rr)
        [Nobs, R2, R2Within, FStatIV]
    else
        [Nobs, R2, FStatIV]
    end
end

end # module
