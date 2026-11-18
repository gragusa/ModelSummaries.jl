
#=
These are the necessary functions to create a table from a regression result.
If the regression result does not provide a function by default, then
within an extension, it is possible to define the necessary function.
=#

##############################################################################
##
## Basic regression model interface functions
##
##############################################################################

"""
    _formula(x::RegressionModel)

Generally a passthrough for the `formula` function from the `StatsModels` package.
Note that the `formula` function returns the `FormulaSchema`.

This function is only used internally in the [`ModelSummaries._responsename`](@ref)
and [`ModelSummaries._coefnames`](@ref) functions. Therefore, if the `RegressionModel`
uses those two functions without using `formula`, this function is not necessary.
"""
_formula(x::RegressionModel) = formula(x)

"""
    _responsename(x::RegressionModel)

Returns the name of the dependent variable in the regression model, parsed from the left
hand side of the formula ([`ModelSummaries._formula`](@ref)). A model type without a
formula needs its own method.
"""
function _responsename(x::RegressionModel)
    out = get_coefname(_formula(x).lhs)
    out isa AbstractVector ? first(out) : out
end

"""
    _coefnames(x::RegressionModel)

Returns a vector of the names of the coefficients in the regression model, parsed from the
right hand side of the formula ([`ModelSummaries._formula`](@ref)). A model type without a
formula needs its own method. Throws if the number of names differs from the number of
coefficients, since the names would then be attached to the wrong estimates.
"""
function _coefnames(x::RegressionModel)
    out = get_coefname(_formula(x).rhs)
    out = out isa AbstractVector ? out : [out]
    ncoef = length(_coef(x))
    length(out) == ncoef || throw(DimensionMismatch(
        "the formula of the $(nameof(typeof(x))) model yields $(length(out)) coefficient \
        names but the model has $ncoef coefficients: $(string.(out))"))
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
    _coeftable(x::RegressionModel)

Returns the model's `StatsAPI.CoefTable`, the source of the p-values and test statistics
shown in the table. A passthrough for `coeftable`. The table must set `pvalcol` and
`teststatcol`; a package extension overrides this method for a model type whose
`coeftable` leaves one of them unset (see [`ModelSummaries.with_teststatcol`](@ref)).
"""
_coeftable(x::RegressionModel) = coeftable(x)

"""
    with_teststatcol(ct::CoefTable, name::AbstractString)

Returns a copy of `ct` whose `teststatcol` is the column named `name`. Throws if no column
has that name, or if `ct` already marks a different column as the test statistic.
"""
function with_teststatcol(ct::CoefTable, name::AbstractString)
    col = findfirst(==(name), ct.colnms)
    col === nothing && throw(ArgumentError(
        "the coefficient table has no column named \"$name\"; its columns are $(ct.colnms)"))
    ct.teststatcol in (0, col) || throw(ArgumentError(
        "the coefficient table marks column $(ct.teststatcol) \
        (\"$(ct.colnms[ct.teststatcol])\") as the test statistic, not \"$name\""))
    CoefTable(ct.cols, ct.colnms, ct.rownms, ct.pvalcol, col)
end

"""
    _coeftable_column(x::RegressionModel, which::Symbol)

Returns the p-values (`which = :pvalue`) or test statistics (`which = :teststat`) of the
model's [`ModelSummaries._coeftable`](@ref), in the order of `coef(x)`.

Rows are matched to coefficients by name, since a `coeftable` may list them in a different
order than `coef` (FixedEffectModels and Regress put the intercept last). Throws if the
table does not mark the column, if its row names are not a permutation of `coefnames(x)`,
or if its first column, reordered, does not reproduce `coef(x)`.
"""
function _coeftable_column(x::RegressionModel, which::Symbol)
    ct = _coeftable(x)
    col = which === :pvalue ? ct.pvalcol :
          which === :teststat ? ct.teststatcol :
          throw(ArgumentError("which = :$which; use :pvalue or :teststat"))
    mname = nameof(typeof(x))
    col > 0 || throw(ArgumentError(
        "the coeftable of the $mname model does not mark its \
        $(which === :pvalue ? "p-value (`pvalcol`)" : "test-statistic (`teststatcol`)") \
        column; its columns are $(ct.colnms)"))
    b = _coef(x)
    rows = if isempty(ct.rownms)
        length(ct.cols[1]) == length(b) || throw(DimensionMismatch(
            "the coeftable of the $mname model has $(length(ct.cols[1])) rows for \
            $(length(b)) coefficients"))
        collect(eachindex(ct.cols[1]))
    else
        rowidx = Dict(nm => i for (i, nm) in pairs(ct.rownms))
        nms = string.(coefnames(x))
        length(rowidx) == length(ct.rownms) == length(nms) &&
        all(in(keys(rowidx)), nms) || throw(ArgumentError(
            "the coeftable rows of the $mname model, $(ct.rownms), are not a permutation \
            of its coefficient names, $nms"))
        [rowidx[nm] for nm in nms]
    end
    isapprox(ct.cols[1][rows], b; nans = true) || throw(ArgumentError(
        "the first column of the coeftable of the $mname model does not reproduce \
        `coef`: $(ct.cols[1][rows]) vs $b"))
    ct.cols[col][rows]
end

"""
    _pvalue(x::RegressionModel)

Returns the p-values of the coefficients, read from the model's `coeftable`.
"""
_pvalue(x::RegressionModel) = _coeftable_column(x, :pvalue)

"""
    _teststat(x::RegressionModel)

Returns the test statistics (t or z) of the coefficients, read from the model's `coeftable`.
"""
_teststat(x::RegressionModel) = _coeftable_column(x, :teststat)

"""
    reference_distribution(x::RegressionModel) -> UnivariateDistribution

The distribution under which the model's `coeftable` computes two-sided p-values from its
test statistics, e.g. `TDist(dof_residual(x))` or `Normal()`. Package extensions define it
for the model types they support; the fallback throws. Only `modelsummary(...; pvalue_note =
true)` calls it, and the note is checked against the `coeftable` p-values.
"""
function reference_distribution(x::RegressionModel)
    throw(ArgumentError(
        "pvalue_note: no `ModelSummaries.reference_distribution` method for \
        $(nameof(typeof(x))); define one, or pass `pvalue_note = false`"))
end

distribution_label(d::TDist) = (ν = only(params(d)); "t($(isinteger(ν) ? Int(ν) : ν))")
distribution_label(::Normal) = "Normal"
function distribution_label(d::UnivariateDistribution)
    throw(ArgumentError("pvalue_note: no label for the reference distribution $d"))
end

"""
    pvalue_note_text(rrs) -> String

The table note stating, per column, the distribution behind the p-values, e.g.
`"p-values: (1) t(97); (2) Normal"`. Throws if the stated distribution of a column does not
reproduce that model's `coeftable` p-values.
"""
function pvalue_note_text(rrs)
    labels = map(enumerate(rrs)) do (i, rr)
        d = reference_distribution(rr)
        p = _pvalue(rr)
        p_ref = 2 .* ccdf.(d, abs.(_teststat(rr)))
        isapprox(p_ref, p; rtol = sqrt(eps()), nans = true) || throw(ArgumentError(
            "pvalue_note: the p-values of model $i ($(nameof(typeof(rr)))) are not two-sided \
            tests against $(distribution_label(d)): $p vs $p_ref"))
        distribution_label(d)
    end
    length(rrs) == 1 && return "p-values: $(only(labels))"
    "p-values: " * join(("($i) $l" for (i, l) in enumerate(labels)), "; ")
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

The default is `false`. A package extension returns `true` for a model type whose model
matrix and response are available, and defines [`ModelSummaries.standardize_coef_values`](@ref)
for it. `modelsummary(...; standardize_coef = true)` throws for a model where this is `false`.

See also [`ModelSummaries.standardize_coef_values`](@ref).
"""
can_standardize(x::RegressionModel) = false

"""
    standardize_coef_values(std_X, std_Y, val)

Standardizes the coefficients by the standard deviation of the variables.
This is useful for comparing the relative importance of the variables in the model.

This function is only used if the [`ModelSummaries.can_standardize`](@ref) function returns `true`.

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
    # Try the value directly, then fall back to its string representation
    r = get(exact_dict, s, nothing)
    r !== nothing && return r
    skey = string(s)
    skey != s && (r = get(exact_dict, skey, nothing); r !== nothing && return r)
    transformer(s, repl_dict)
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
Package extensions define methods for model types that record their estimator. This
fallback reads a `vcov_type` property if the model has one and otherwise returns "IID".
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
