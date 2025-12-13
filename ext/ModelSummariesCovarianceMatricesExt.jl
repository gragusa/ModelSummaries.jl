module ModelSummariesCovarianceMatricesExt

using ModelSummaries
using CovarianceMatrices
using StatsAPI
using StatsBase

"""
    ModelSummaries.materialize_vcov(estimator, model)

Compute the variance-covariance matrix for a regression model using a CovarianceMatrices.jl estimator.

This method enables integration between ModelSummaries.jl and CovarianceMatrices.jl, allowing
users to specify robust variance estimators (HC0-HC5, HAC, cluster-robust CR0-CR3, etc.) when
creating regression tables.

# Examples
```julia
using ModelSummaries, CovarianceMatrices, GLM, DataFrames

# Fit a regression model
df = DataFrame(y = randn(100), x1 = randn(100), x2 = randn(100), id = rand(1:10, 100))
model = lm(@formula(y ~ x1 + x2), df)

# Create table with HC3 robust standard errors
modelsummary(model + vcov(HC3()))

# Or with HAC standard errors
modelsummary(model + vcov(HAC(Bartlett, 5)))

# Or with cluster-robust standard errors (CR0, CR1, CR2, CR3)
modelsummary(model + vcov(CR0(:id)))
```
"""
function ModelSummaries.materialize_vcov(
    estimator::CovarianceMatrices.AbstractAsymptoticVarianceEstimator,
    model::StatsAPI.RegressionModel
)
    return StatsBase.vcov(estimator, model)
end

end
