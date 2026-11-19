module ModelSummariesRegressExt

using Regress: Regress, IVEstimator, IVMatrixEstimator, OLSEstimator, OLSMatrixEstimator,
               has_fe
using ModelSummaries: ModelSummaries, CoefName, FixedEffectValue, FStat, FStatIV,
                      FStatIVPValue, FStatPValue, InterceptCoefName, Nobs, R2, R2Within,
                      RegressionType, UnnamedFixedEffectCoefName, VcovType
using CovarianceMatrices: CR, CovarianceMatrix, clusters, estimator, nclusters
using Distributions: Normal, TDist
using StatsModels: StatsModels
using StatsAPI: coefnames, coeftable, dof_residual, vcov

# Fits from `ols(df, formula)` and `iv(estimator, df, formula)`.
const FormulaFit = Union{OLSEstimator, IVEstimator}
# Fits from `ols(X, y)` and `iv(estimator, Z, X, y)`: no formula, no response name, and
# absorbed fixed effects given as unnamed group vectors.
const MatrixFit = Union{OLSMatrixEstimator, IVMatrixEstimator}
const RegressFit = Union{FormulaFit, MatrixFit}

##############################################################################
## Statistics
##############################################################################

# F-statistic
ModelSummaries.FStat(x::OLSEstimator) = FStat(x.F)
ModelSummaries.FStat(x::IVEstimator) = FStat(x.F)
ModelSummaries.FStatPValue(x::OLSEstimator) = FStatPValue(x.p)
ModelSummaries.FStatPValue(x::IVEstimator) = FStatPValue(x.p)

# First-stage F-statistic (IV only)
ModelSummaries.FStatIV(x::IVEstimator) = FStatIV(x.F_kp)
ModelSummaries.FStatIVPValue(x::IVEstimator) = FStatIVPValue(x.p_kp)
function ModelSummaries.applies(::Type{<:Union{FStatIV, FStatIVPValue}},
        ::Union{OLSEstimator, OLSMatrixEstimator})
    false
end

# Within R²
ModelSummaries.R2Within(x::FormulaFit) = R2Within(x.r2_within)
ModelSummaries.applies(::Type{R2Within}, x::RegressFit) = has_fe(x)

# Regress stores neither the within R² of a matrix fit nor the joint first-stage F of a
# matrix IV fit. `first_stage(m)` reports a robust F per endogenous variable, which is the
# joint Kleibergen-Paap F only when there is one, so it is not used in their place.
function not_stored(what, x, remedy)
    throw(ArgumentError("Regress does not store the $what of a $(nameof(typeof(x))) \
        (a fit from matrices); $remedy"))
end
function not_stored(S::Type, x, what)
    not_stored(what, x,
        "leave $S out of `regression_statistics` for a table with this model")
end
ModelSummaries.R2Within(x::MatrixFit) = not_stored(R2Within, x, "within R²")
ModelSummaries.FStatIV(x::IVMatrixEstimator) = not_stored(FStatIV, x, "first-stage F")
function ModelSummaries.FStatIVPValue(x::IVMatrixEstimator)
    not_stored(FStatIVPValue, x, "first-stage F")
end

# The estimator behind `stderror`: Regress's default, or the one attached by `+ vcov(...)`.
function ModelSummaries.VcovType(x::RegressFit)
    VcovType(ModelSummaries.vcov_type_name(x.vcov_estimator, x))
end

# Regress's coeftable leaves `teststatcol` unset.
function ModelSummaries.inference_coeftable(x::RegressFit)
    ModelSummaries.with_teststatcol(coeftable(x), "t-stat")
end
function ModelSummaries.reference_distribution(x::RegressFit)
    TDist(dof_residual(x))
end

# Regression Type
ModelSummaries.RegressionType(x::OLSEstimator) = RegressionType(Normal(), false)
ModelSummaries.RegressionType(x::IVEstimator) = RegressionType(Normal(), true)
ModelSummaries.RegressionType(x::OLSMatrixEstimator) = RegressionType(Normal(), false)
ModelSummaries.RegressionType(x::IVMatrixEstimator) = RegressionType(Normal(), true)

##############################################################################
## Names for matrix fits
##############################################################################

# One name per column of `X`, from the fit's `coefnames`. A column named "(Intercept)"
# becomes `InterceptCoefName` so that it shares the intercept row of formula fits.
function ModelSummaries._coefnames(x::MatrixFit)
    [nm == "(Intercept)" ? InterceptCoefName() : CoefName(nm) for nm in coefnames(x)]
end

# A matrix fit has no response name; the dependent-variable cell is left empty.
ModelSummaries._responsename(x::MatrixFit) = CoefName("")

##############################################################################
## Coefficient Names (for FE terms in formula)
##############################################################################

# Handle fe() terms from Regress formula
function ModelSummaries.get_coefname(x::StatsModels.FunctionTerm{typeof(Regress.fe)})
    ModelSummaries.CoefName(string(x.exorig.args[end]))
end

##############################################################################
## Clusters of the estimator behind `stderror`
##############################################################################

# One row per clustering dimension of `vcov_estimator`, and none when it is not
# cluster-robust: fixed-effect and `save_cluster` columns the standard errors do not
# cluster on are not listed. A dimension named by column (`CR1(:year)`) shows the column
# name; one given as data (`CR1(df.year)`, a `CachedCR`) shows `Cluster k`, k its position
# in the estimator. Group counts come from the resolved estimator that `vcov` reports.
function vcov_cluster_entries(rr::RegressFit)
    k = rr.vcov_estimator
    k isa CR || return nothing
    V = vcov(rr)
    V isa CovarianceMatrix || throw(ArgumentError(
        "vcov of a $(nameof(typeof(rr))) with a cluster-robust estimator is a " *
        "$(nameof(typeof(V))), not a CovarianceMatrix; the number of clusters is unknown"))
    names = [d isa Symbol ? string(d) : nothing for d in clusters(k)]
    ModelSummaries.cluster_entries(names, collect(nclusters(estimator(V))))
end

##############################################################################
## Fixed Effects and Clusters for OLSEstimator
##############################################################################

function ModelSummaries.other_stats(rr::OLSEstimator, s::Symbol)
    if s == :fe
        has_fe(rr) || return nothing
        ModelSummaries.fixed_effect_entries(rr.formula.rhs, has_fe)
    elseif s == :clusters
        vcov_cluster_entries(rr)
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
        vcov_cluster_entries(rr)
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
## Fixed Effects, Clusters, and First Stage for matrix fits
##############################################################################

# Absorbed fixed effects are group vectors without names: `Fixed effect k`, k their
# position in the `fe` keyword of the fit.
function matrix_fixed_effect_entries(rr::MatrixFit)
    has_fe(rr) || return nothing
    [UnnamedFixedEffectCoefName(k) => FixedEffectValue(true)
     for k in eachindex(rr.fe_groups)]
end

function ModelSummaries.other_stats(rr::OLSMatrixEstimator, s::Symbol)
    s == :fe ? matrix_fixed_effect_entries(rr) :
    s == :clusters ? vcov_cluster_entries(rr) : nothing
end

function ModelSummaries.other_stats(rr::IVMatrixEstimator, s::Symbol)
    if s == :fe
        matrix_fixed_effect_entries(rr)
    elseif s == :clusters
        vcov_cluster_entries(rr)
    elseif s == :first_stage
        not_stored("first-stage F", rr,
            "set `print_first_stage_section = false` for a table with this model")
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

# Without the within R² and first-stage F, which Regress does not store for matrix fits.
ModelSummaries.default_regression_statistics(rr::MatrixFit) = [Nobs, R2]

end # module
