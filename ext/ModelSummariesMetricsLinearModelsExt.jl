module ModelSummariesMetricsLinearModelsExt

using MetricsLinearModels
using ModelSummaries
using Distributions
using StatsModels

# Import model types
using MetricsLinearModels: OLSEstimator, IVEstimator, ModelWithVcov, has_iv, has_fe

##############################################################################
## Statistics for OLSEstimator and IVEstimator
##############################################################################

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

# Regression Type
ModelSummaries.RegressionType(x::OLSEstimator) = RegressionType(Normal(), false)
ModelSummaries.RegressionType(x::IVEstimator) = RegressionType(Normal(), true)

##############################################################################
## Statistics for ModelWithVcov (delegates to wrapped model or uses stored stats)
##############################################################################

# F-statistic: Use the robust Wald F from ModelWithVcov (computed with the new vcov)
ModelSummaries.FStat(x::ModelWithVcov) = FStat(x.F)
ModelSummaries.FStatPValue(x::ModelWithVcov) = FStatPValue(x.p)

# First-stage F-statistic: Use the recomputed first-stage F from ModelWithVcov
# For OLS-wrapped ModelWithVcov, F_kp is Nothing; for IV-wrapped it's the recomputed value
ModelSummaries.FStatIV(x::ModelWithVcov) = FStatIV(x.F_kp)
ModelSummaries.FStatIVPValue(x::ModelWithVcov) = FStatIVPValue(x.p_kp)

# Within R²: Delegate to wrapped model (not vcov-dependent)
ModelSummaries.R2Within(x::ModelWithVcov) = has_fe(x) ? R2Within(x.model.r2_within) : R2Within(nothing)

# Regression Type: Delegate to wrapped model (OLS vs IV)
ModelSummaries.RegressionType(x::ModelWithVcov) = RegressionType(Normal(), has_iv(x))

##############################################################################
## Coefficient Names (for FE terms in formula)
##############################################################################

# Handle fe() terms from MetricsLinearModels formula
ModelSummaries.get_coefname(x::StatsModels.FunctionTerm{typeof(MetricsLinearModels.fe)}) =
    ModelSummaries.CoefName(string(x.exorig.args[end]))

##############################################################################
## Fixed Effects and Clusters for OLSEstimator
##############################################################################

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
        hasfield(typeof(rr.fes), :clusters) && !isempty(rr.fes.clusters) || return nothing
        cluster_names = keys(rr.fes.clusters)
        collect(ModelSummaries.ClusterCoefName.(string.(cluster_names)) .=>
                ModelSummaries.ClusterValue.(length.(unique.(values(rr.fes.clusters)))))
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
## Fixed Effects, Clusters, and First Stage for ModelWithVcov
## Delegates to wrapped model, except first_stage uses ModelWithVcov's recomputed F_kp
##############################################################################

function ModelSummaries.other_stats(rr::ModelWithVcov, s::Symbol)
    if s == :fe
        # Delegate to wrapped model
        return ModelSummaries.other_stats(rr.model, :fe)
    elseif s == :clusters
        # Delegate to wrapped model
        return ModelSummaries.other_stats(rr.model, :clusters)
    elseif s == :first_stage
        # Use ModelWithVcov's recomputed first-stage F (with new vcov)
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

function ModelSummaries.default_regression_statistics(rr::ModelWithVcov)
    # Delegate to wrapped model's logic
    if has_iv(rr)
        # IV model
        if has_fe(rr)
            [Nobs, R2, R2Within, FStatIV]
        else
            [Nobs, R2, FStatIV]
        end
    else
        # OLS model
        has_fe(rr) ? [Nobs, R2, R2Within] : [Nobs, R2]
    end
end

end # module
