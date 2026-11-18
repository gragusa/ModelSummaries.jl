module ModelSummaries

##############################################################################
## Dependencies
##############################################################################

using StatsBase: StatsBase, CoefTable, adjr2, aic, aicc, bic, confint, r2
using StatsModels: StatsModels, AbstractTerm, CategoricalTerm, InteractionTerm,
                   InterceptTerm, MatrixTerm, RegressionModel, Term, formula
using Statistics: Statistics
using StatsAPI: StatsAPI
import StatsAPI: coef, coeftable, stderror, dof_residual, coefnames, islinear, nobs

using Distributions: Distributions, InverseGaussian, NegativeBinomial, Normal, TDist,
                     UnivariateDistribution, ccdf, loglikelihood, params
using Format: Format, format
using SummaryTables: SummaryTables, Cell, Table, Concat, Superscript
using WriteDocx: WriteDocx

##############################################################################
## Exported methods and types
##############################################################################

export modelsummary, BackendMath, Checkmark
export Nobs, R2, R2McFadden, R2CoxSnell, R2Nagelkerke,
       R2Deviance, AdjR2, AdjR2McFadden, AdjR2Deviance, DOF, LogLikelihood, AIC, BIC, AICC,
       FStat, FStatPValue, FStatIV, FStatIVPValue, R2Within, PseudoR2, AdjPseudoR2,
       VcovType, Spacer
export TStat, StdError, ConfInt, RegressionType

# Statistics type system
export AbstractRegressionStatistic

##############################################################################
## Load files
##############################################################################

# backend-adaptive math rendering
include("BackendMath.jl")

# main types
include("RegressionStatistics.jl")
include("coefnames.jl")
include("regressionResults.jl")

# table building helpers (Cell formatting, display names)
include("table_builder.jl")

# main function
include("modelsummary.jl")

end
