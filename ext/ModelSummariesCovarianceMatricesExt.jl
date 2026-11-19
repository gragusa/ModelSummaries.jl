module ModelSummariesCovarianceMatricesExt

# Display names for CovarianceMatrices estimators, used by the `VcovType` row. Attaching an
# estimator to a model (`model + vcov(estimator)`) is the job of the package that owns the
# model type or `VcovSpec`; ModelSummaries reads the result through StatsAPI.

using ModelSummaries: ModelSummaries
using CovarianceMatrices: CovarianceMatrices, CovarianceMatrix, Fixed, HAC, HR0, HR1, HR2,
                          HR3, bandwidth
using StatsAPI: RegressionModel, vcov

##############################################################################
##
## vcov_type_name methods for CovarianceMatrices estimators
##
##############################################################################

# HC0-HC3 are aliases of HR0-HR3; HC is the more common notation.
ModelSummaries.vcov_type_name(::HR0) = "HC0"
ModelSummaries.vcov_type_name(::HR1) = "HC1"
ModelSummaries.vcov_type_name(::HR2) = "HC2"
ModelSummaries.vcov_type_name(::HR3) = "HC3"

# Kernel name without the suffix: BartlettKernel -> Bartlett
_hac_kernel_name(v::HAC) = replace(string(nameof(typeof(v))), "Kernel" => "")

function _format_bandwidth(bw::Real)
    bw == floor(bw) ? string(Int(bw)) : string(round(bw, digits = 2))
end

# Fixed bandwidth: Bartlett(5) -> "Bartlett(5)"
function ModelSummaries.vcov_type_name(v::HAC{<:Fixed})
    string(_hac_kernel_name(v), "(", _format_bandwidth(bandwidth(v)), ")")
end

# Data-driven bandwidth: Bartlett{Andrews}() -> "Bartlett(Andrews)". The estimator carries
# only the selection rule; the selected bandwidth belongs to a computed estimate.
function ModelSummaries.vcov_type_name(v::HAC{G}) where {G}
    string(_hac_kernel_name(v), "(", nameof(G), ")")
end

function ModelSummaries.vcov_type_name(v::HAC{<:Fixed}, ::RegressionModel)
    ModelSummaries.vcov_type_name(v)
end

# On a fitted model, a data-driven kernel also reports the bandwidth behind `vcov(m)`:
# "Bartlett(Andrews), bw: 4.93". A model whose `vcov` is not a `CovarianceMatrix` keeps no
# record of the bandwidth, and the label names the rule only.
function ModelSummaries.vcov_type_name(v::HAC, m::RegressionModel)
    name = ModelSummaries.vcov_type_name(v)
    V = vcov(m)
    V isa CovarianceMatrix || return name
    bw = bandwidth(V)
    bw === nothing && throw(ArgumentError(
        "the covariance matrix of $(typeof(m)) was computed with $(name) but records no bandwidth"))
    return string(name, ", bw: ", _format_bandwidth(bw))
end

end
