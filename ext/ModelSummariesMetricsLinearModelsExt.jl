module ModelSummariesMetricsLinearModelsExt

using MetricsLinearModels
using ModelSummaries
using Distributions
using StatsModels

# Import model types
using MetricsLinearModels: OLSEstimator, IVEstimator, has_iv, has_fe

# --- Statistics ---

# F-statistic
ModelSummaries.FStat(x::OLSEstimator) = FStat(x.F)
ModelSummaries.FStat(x::IVEstimator) = FStat(x.F)
ModelSummaries.FStatPValue(x::OLSEstimator) = FStatPValue(x.p)
ModelSummaries.FStatPValue(x::IVEstimator) = FStatPValue(x.p)

# First-stage F-statistic (IV only)
ModelSummaries.FStatIV(x::OLSEstimator) = FStatIV(nothing)
ModelSummaries.FStatIV(x::IVEstimator) = FStatIV(x.F_kp)
ModelSummaries.FStatIVPValue(x::OLSEstimator) = FStatIVPValue(nothing)
ModelSummaries.FStatIVPValue(x::IVEstimator) = FStatIVPValue(x.p_kp)

# Within R²
ModelSummaries.R2Within(x::OLSEstimator) = has_fe(x) ? R2Within(x.r2_within) : R2Within(nothing)
ModelSummaries.R2Within(x::IVEstimator) = has_fe(x) ? R2Within(x.r2_within) : R2Within(nothing)

# --- Regression Type ---

ModelSummaries.RegressionType(x::OLSEstimator) = RegressionType(Normal(), false)
ModelSummaries.RegressionType(x::IVEstimator) = RegressionType(Normal(), true)

# --- Coefficient Names (for FE terms in formula) ---

# Handle fe() terms from MetricsLinearModels formula
ModelSummaries.get_coefname(x::StatsModels.FunctionTerm{typeof(MetricsLinearModels.fe)}) =
    ModelSummaries.CoefName(string(x.exorig.args[end]))

# --- Fixed Effects and Clusters ---

function ModelSummaries.other_stats(rr::OLSEstimator, s::Symbol)
    if s == :fe
        !has_fe(rr) && return nothing
        out = []
        fe_set = has_fe.(rr.formula.rhs)
        for (i, v) in enumerate(fe_set)
            if v && !isa(fe_set, Bool)
                push!(out, ModelSummaries.FixedEffectCoefName(ModelSummaries.get_coefname(rr.formula.rhs[i])))
            elseif v
                push!(out, ModelSummaries.FixedEffectCoefName(ModelSummaries.get_coefname(rr.formula.rhs)))
            end
        end
        length(out) > 0 ? (out .=> ModelSummaries.FixedEffectValue(true)) : nothing
    elseif s == :clusters
        # Check if cluster variables are stored
        hasfield(typeof(rr.fes), :cluster_vars) && !isempty(rr.fes.cluster_vars) || return nothing
        cluster_names = keys(rr.fes.cluster_vars)
        collect(ModelSummaries.ClusterCoefName.(string.(cluster_names)) .=>
                ModelSummaries.ClusterValue.(length.(values(rr.fes.cluster_vars))))
    else
        nothing
    end
end

function ModelSummaries.other_stats(rr::IVEstimator, s::Symbol)
    if s == :fe
        !has_fe(rr) && return nothing
        out = []
        fe_set = has_fe.(rr.formula.rhs)
        for (i, v) in enumerate(fe_set)
            if v && !isa(fe_set, Bool)
                push!(out, ModelSummaries.FixedEffectCoefName(ModelSummaries.get_coefname(rr.formula.rhs[i])))
            elseif v
                push!(out, ModelSummaries.FixedEffectCoefName(ModelSummaries.get_coefname(rr.formula.rhs)))
            end
        end
        length(out) > 0 ? (out .=> ModelSummaries.FixedEffectValue(true)) : nothing
    elseif s == :clusters
        isnothing(rr.postestimation) && return nothing
        cluster_vars = rr.postestimation.cluster_vars
        isempty(cluster_vars) && return nothing
        cluster_names = keys(cluster_vars)
        collect(ModelSummaries.ClusterCoefName.(string.(cluster_names)) .=>
                ModelSummaries.ClusterValue.(length.(unique.(values(cluster_vars)))))
    else
        nothing
    end
end

# --- Default Statistics ---

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
