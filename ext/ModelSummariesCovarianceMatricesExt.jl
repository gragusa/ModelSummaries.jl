module ModelSummariesCovarianceMatricesExt

# Display names for CovarianceMatrices estimators, used by the `VcovType` row. Attaching an
# estimator to a model (`model + vcov(estimator)`) is the job of the package that owns the
# model type or `VcovSpec`; ModelSummaries reads the result through StatsAPI.

using ModelSummaries
using CovarianceMatrices

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
        return string(typename, "(", round(bw_val, digits = 2), ")")
    end
end

function ModelSummaries.vcov_type_name(v::CovarianceMatrices.HAC)
    typename = _hac_kernel_name(v)
    bw_val = v.bw[1]
    if bw_val == 0.0
        # Bandwidth not yet computed
        return string(typename, "(auto)")
    else
        return string(typename, "(auto), bw: ", round(bw_val, digits = 2))
    end
end

end
