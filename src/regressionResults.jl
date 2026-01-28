
#=
These are the necessary functions to create a table from a regression result.
If the regression result does not provide a function by default, then
within an extension, it is possible to define the necessary function.
=#

##############################################################################
##
## Basic regression model interface functions
##
## Note: VcovSpec and RegressionModelWithVcov are defined in the
## CovarianceMatrices extension (ModelSummariesCovarianceMatricesExt).
## The model + vcov() syntax only works when CovarianceMatrices is loaded.
##
##############################################################################

"""
    _formula(x::RegressionModel)

Generally a passthrough for the `formula` function from the `StatsModels` package.
Note tha the `formula` function returns the `FormulaSchema`.

This function is only used internally in the [`ModelSummarys._responsename`](@ref)
and [`ModelSummarys._coefnames`](@ref) functions. Therefore, if the `RegressionModel`
uses those two functions without using `formula`, this function is not necessary.
"""
_formula(x::RegressionModel) = formula(x)

"""
    _responsename(x::RegressionModel)

Returns the name of the dependent variable in the regression model.
The default  is to return a parsed version of the left hand side of formula ([`ModelSummarys._formula`](@ref)),
but if that is not available, then it will return the `StatsAPI.responsename` function.
"""
function _responsename(x::RegressionModel)
    try
        out = get_coefname(_formula(x).lhs)
    catch
        out = get_coefname(responsename(x))
    end
    if isa(out, AbstractVector)
        out = first(out)
    end
    out
end

"""
    _coefnames(x::RegressionModel)

Returns a vector of the names of the coefficients in the regression model.
The default  is to return a parsed version of the formula ([`ModelSummarys._formula`](@ref)),
but if that is not available, then it will return the `StatsAPI.coefnames` function.
"""
function _coefnames(x::RegressionModel)
    try
        out = get_coefname(_formula(x).rhs)
    catch
        out = get_coefname(coefnames(x))
    end
    if !isa(out, AbstractVector)
        out = [out]
    end
    out
end

"""
    _coef(x::RegressionModel)

Returns a vector of the coefficients in the regression model.
By default, is just a passthrough for the `coef` function from the `StatsModels` package.
"""
_coef(x::RegressionModel) = coef(x)

"""
    _stderror(x::RegressionModel)

Returns a vector of the standard errors of the coefficients in the regression model.
By default, is just a passthrough for the `stderror` function from the `StatsModels` package.
"""
_stderror(x::RegressionModel) = stderror(x)

"""
    _dof_residual(x::RegressionModel)

Returns the degrees of freedom of the residuals in the regression model.
By default, is just a passthrough for the `dof_residual` function from the `StatsModels` package.
"""
_dof_residual(x::RegressionModel) = dof_residual(x)

"""
    _pvalue(x::RegressionModel)

Returns a vector of the p-values of the coefficients in the regression model.
"""
function _pvalue(x::RegressionModel)
    tt = _coef(x) ./ _stderror(x)
    ccdf.(Ref(FDist(1, _dof_residual(x))), abs2.(tt))
end

"""
    _islinear(x::RegressionModel)

Returns a boolean indicating whether the regression model is linear.
"""
_islinear(x::RegressionModel) = islinear(x)

"""
    can_standardize(x::RegressionModel)

Returns a boolean indicating whether the coefficients can be standardized.
standardized coefficients are coefficients that are scaled by the standard deviation of the
variables. This is useful for comparing the relative importance of the variables in the model.

This is only possible of the `RegressionModel` includes the model matrix or the
standard deviation of the dependent variable. If the `RegressionModel` does not include
either of these, then this function should return `false`.

See also [`ModelSummarys.standardize_coef_values`](@ref).
"""
function can_standardize(x::T) where {T <: RegressionModel}
    @warn "standardize_coef is not possible for $T"
    false
end

"""
    standardize_coef_values(std_X, std_Y, val)

Standardizes the coefficients by the standard deviation of the variables.
This is useful for comparing the relative importance of the variables in the model.

This function is only used if the [`ModelSummarys.can_standardize`](@ref) function returns `true`.

### Arguments
- `std_X::Real`: The standard deviation of the independent variable.
- `std_Y::Real`: The standard deviation of the dependent variable.
- `val::Real`: The value to be standardized (either the coefficient or the standard error).

!!! note
    If the standard deviation of the independent variable is 0, then the interpretation of the
    coefficient is how many standard deviations of the dependent variable away from 0 is the intercept.
    In this case, the function returns `val / std_Y`.

    Otherwise, the function returns `val * std_X / std_Y`.
"""
function standardize_coef_values(std_X, std_Y, val)
    if std_X == 0 # constant has 0 std, so the interpretation is how many Y std away from 0 is the intercept
        val / std_Y
    else
        val * std_X / std_Y
    end
end

transformer(s::Nothing, repl_dict::AbstractDict) = s
function transformer(s, repl_dict::AbstractDict)
    for (old, new) in repl_dict
        s = replace(s, old => new)
    end
    return s
end

function replace_name(s::Union{AbstractString, AbstractCoefName}, exact_dict, repl_dict)
    get(exact_dict, s, transformer(s, repl_dict))
end
function replace_name(s::Tuple{<:AbstractCoefName, <:AbstractString}, exact_dict, repl_dict)
    (replace_name(s[1], exact_dict, repl_dict), s[2])
end
replace_name(s::Nothing, args...) = s

function RegressionType(x::RegressionModel)
    _islinear(x) ? RegressionType(Normal()) : RegressionType("NL")
end

make_reg_stats(rr, stat::Type{<:AbstractRegressionStatistic}) = stat(rr)
make_reg_stats(rr, stat) = stat
function make_reg_stats(rr, stat::Pair{<:Any, <:AbstractString})
    make_reg_stats(rr, first(stat)) => last(stat)
end

function default_regression_statistics(x::AbstractRenderType, rr::RegressionModel)
    default_regression_statistics(rr)
end
"""
    default_regression_statistics(rr::RegressionModel)

Returns a vector of [`AbstractRegressionStatistic`](@ref) objects. This is used to display the
statistics in the table. This is customizable for each `RegressionModel` type. The default
is to return a vector of `Nobs` and `R2`.
"""
default_regression_statistics(rr::RegressionModel) = [Nobs, R2]

"""
    other_stats(rr::RegressionModel, s::Symbol)

Returns any other statistics to be displayed. This is used (if the appropriate extension is loaded)
to display the fixed effects in a FixedEffectModel (or GLFixedEffectModel),
clusters in those two, or Random Effects in a MixedModel. For other regressions, this
returns `nothing`.
"""
other_stats(x::RegressionModel, s::Symbol) = nothing

"""
    VcovType(x::RegressionModel)

Returns a VcovType object indicating the type of variance-covariance estimator used.
For models with custom vcov (RegressionModelWithVcov), the type is determined by
the CovarianceMatrices extension. For other models, this checks for vcov_type property
or returns "IID" as default.
"""
function VcovType(x::RegressionModel)
    # Check for vcov_type property (common in FixedEffectModels.jl)
    if hasproperty(x, :vcov_type)
        s = string(x.vcov_type)
        if s == "Simple covariance estimator"
            return VcovType("IID")
        elseif occursin("Robust", s) || occursin("Heteroskedastic", s)
            return VcovType("Robust")
        elseif occursin("Cluster", s)
            return VcovType("Cluster")
        end
        return VcovType(s)
    end

    # Fallback/Default
    return VcovType("IID")
end

##############################################################################
##
## vcov_type_name - helper for display
##
##############################################################################

"""
    vcov_type_name(v) -> String

Return a readable name for the variance-covariance estimator type.
Used in display output to indicate what type of standard errors are shown.
"""
vcov_type_name(v) = string(typeof(v).name.name)
vcov_type_name(::AbstractMatrix) = "Custom"
vcov_type_name(::Function) = "Function"

##############################################################################
##
## materialize_vcov - stub for extension point
##
## The actual implementation is in the CovarianceMatrices extension.
##
##############################################################################

"""
    materialize_vcov(estimator, model::RegressionModel)

Produce the variance–covariance matrix for `model` given an estimator object.
This is the extension point for third-party estimators: define a method that
returns the desired matrix.

The actual implementation for CovarianceMatrices.jl estimators is provided
by the ModelSummariesCovarianceMatricesExt extension.
"""
function materialize_vcov end
