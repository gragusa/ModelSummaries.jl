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

##############################################################################
##
## vcov_type_name methods for CovarianceMatrices estimators
##
##############################################################################

# HC/HR estimators - show as "HC" (more common notation)
# In CovarianceMatrices.jl, HC0-HC3 are type aliases for HR0-HR3
ModelSummaries.vcov_type_name(::CovarianceMatrices.HR0) = "HC0"
ModelSummaries.vcov_type_name(::CovarianceMatrices.HR1) = "HC1"
ModelSummaries.vcov_type_name(::CovarianceMatrices.HR2) = "HC2"
ModelSummaries.vcov_type_name(::CovarianceMatrices.HR3) = "HC3"

# HAC estimators with bandwidth
# Fixed bandwidth: Bartlett(5) -> "Bartlett(5)"
# Auto bandwidth: Bartlett(NeweyWest) -> "Bartlett(auto), bw: 4.27"

# Helper to get clean kernel name (BartlettKernel -> Bartlett)
function _hac_kernel_name(v::CovarianceMatrices.HAC)
    typename = string(typeof(v).name.name)
    return replace(typename, "Kernel" => "")
end

function ModelSummaries.vcov_type_name(v::CovarianceMatrices.HAC{<:CovarianceMatrices.Fixed})
    typename = _hac_kernel_name(v)
    bw_val = v.bw[1]
    # Show as integer if it's a whole number
    if bw_val == floor(bw_val)
        return string(typename, "(", Int(bw_val), ")")
    else
        return string(typename, "(", round(bw_val, digits=2), ")")
    end
end

function ModelSummaries.vcov_type_name(v::CovarianceMatrices.HAC)
    typename = _hac_kernel_name(v)
    bw_val = v.bw[1]
    if bw_val == 0.0
        # Bandwidth not yet computed
        return string(typename, "(auto)")
    else
        return string(typename, "(auto), bw: ", round(bw_val, digits=2))
    end
end

end
