module ModelSummaries

##############################################################################
## Dependencies
##############################################################################

using StatsBase
using StatsModels
using Statistics
using StatsAPI
import StatsAPI: coef, stderror, dof_residual, responsename, coefnames, islinear, nobs, vcov

using Distributions
using Format
using LinearAlgebra: issymmetric
using SummaryTables
using SummaryTables: Cell, Table, Concat, Superscript, Subscript

##############################################################################
## Exported methods and types
##############################################################################

export modelsummary
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

# main types
include("RegressionStatistics.jl")
include("coefnames.jl")
include("regressionResults.jl")

# table building helpers (Cell formatting, display names)
include("table_builder.jl")

# main function
include("modelsummary.jl")

end
