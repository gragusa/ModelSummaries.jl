# Helper functions for building SummaryTables cells

"""
    format_number(x::Float64; digits=3)

Format a floating-point number for display in the table.
"""
format_number(x::Float64; digits=3) = format(x; precision=digits, commas=false)
format_number(x::Real; digits=3) = format(Float64(x); precision=digits, commas=false)
format_number(x::Int; digits=3) = format(x, commas=true)
format_number(::Nothing; digits=3) = ""
format_number(::Missing; digits=3) = ""

"""
    significance_stars(pval; breaks=[0.001, 0.01, 0.05])

Return significance stars string based on p-value.
"""
function significance_stars(pval; breaks=[0.001, 0.01, 0.05])
    @assert issorted(breaks)
    (isnan(pval) || pval < 0) && return ""
    i = findfirst(pval .<= breaks)
    i === nothing ? "" : "*"^(length(breaks) - i + 1)
end

"""
    make_coef_cell(cv::CoefValue; digits=3, stars=false, halign=:right)

Create a Cell for a coefficient value, optionally with significance stars.
"""
function make_coef_cell(cv::CoefValue; digits=3, stars=false, halign=:right)
    s = format_number(cv.val; digits)
    if stars
        star_str = significance_stars(cv.pvalue)
        if !isempty(star_str)
            return Cell(Concat(s, Superscript(star_str)); halign)
        end
    end
    Cell(s; halign)
end

"""
    make_understat_cell(us::AbstractUnderStatistic; digits=3, halign=:right)

Create a Cell for an under-statistic (standard error, t-stat).
"""
function make_understat_cell(us::AbstractUnderStatistic; digits=3, halign=:right)
    Cell("(" * format_number(value(us); digits) * ")"; halign)
end

function make_understat_cell(ci::ConfInt; digits=3, halign=:right)
    lo = format_number(value(ci)[1]; digits)
    hi = format_number(value(ci)[2]; digits)
    Cell("($lo, $hi)"; halign)
end

make_understat_cell(::Missing; digits=3, halign=:right) = Cell(nothing; halign)
make_understat_cell(::Nothing; digits=3, halign=:right) = Cell(nothing; halign)

# Display name functions for coefficient names

"""
    display_name(x)

Convert a coefficient name or other value to a display string.
"""
display_name(x::CoefName) = x.name
display_name(x::InteractedCoefName) = join(display_name.(x.names), " \u00d7 ")
display_name(x::CategoricalCoefName) = "$(x.name): $(x.level)"
display_name(x::InterceptCoefName) = "(Intercept)"
display_name(x::FixedEffectCoefName) = display_name(x.name)
display_name(x::ClusterCoefName) = display_name(x.name)
display_name(x::FirstStageCoefName) = display_name(x.name)
display_name(x::RandomEffectCoefName) = display_name(x.rhs) * " | " * display_name(x.lhs)
display_name(x::AbstractString) = String(x)
display_name(x::AbstractCoefName) = string(x)

# Suffix functions (customizable by users)

"""Suffix appended to fixed effect names."""
fe_suffix() = " Fixed Effects"
"""Suffix appended to cluster variable names."""
cluster_suffix() = " Clustering"
"""Suffix appended to first-stage statistic names."""
first_stage_suffix() = " First Stage"

# Display value for regression types

"""
    display_regtype(x::RegressionType)

Convert a RegressionType to a display string.
"""
function display_regtype(x::RegressionType)
    x.is_iv && return "IV"
    _distribution_name(x.val)
end

_distribution_name(x::Normal) = "OLS"
_distribution_name(x::InverseGaussian) = "Inverse Gaussian"
_distribution_name(x::NegativeBinomial) = "Negative Binomial"
_distribution_name(x::AbstractString) = x
function _distribution_name(x::D) where {D<:UnivariateDistribution}
    string(Base.typename(D).wrapper)
end

# Format statistic values for display

"""
    format_stat_value(x; digits=3)

Format a regression statistic value for display in a cell.
"""
format_stat_value(x::AbstractRegressionStatistic; digits=3) = format_number(value(x); digits)
format_stat_value(x::Nobs; digits=3) = value(x) === nothing ? "" : format(value(x), commas=true)
format_stat_value(x::DOF; digits=3) = value(x) === nothing ? "" : format(value(x), commas=true)
format_stat_value(x::VcovType; digits=3) = something(value(x), "")
format_stat_value(::Spacer; digits=3) = ""
format_stat_value(::Missing; digits=3) = ""
format_stat_value(::Nothing; digits=3) = ""
format_stat_value(x::AbstractString; digits=3) = x

# Format other stat values (FE, clusters, etc.)

"""
    format_other_stat(x; digits=3)

Format values from combine_other_statistics for display.
"""
format_other_stat(x; digits=3) = string(x)
format_other_stat(x::AbstractString; digits=3) = x
format_other_stat(x::Missing; digits=3) = ""
format_other_stat(x::ClusterValue; digits=3) = value(x) > 0 ? "Yes" : ""
format_other_stat(x::RandomEffectValue; digits=3) = format_number(value(x); digits)
format_other_stat(x::FirstStageValue; digits=3) = value(x) === nothing ? "" : format_number(value(x); digits)
format_other_stat(x::Float64; digits=3) = format_number(x; digits)
format_other_stat(x::Int; digits=3) = format(x, commas=true)
format_other_stat(x::Bool; digits=3) = x ? "Yes" : ""

# Stat label helper

"""
    stat_label(x)

Get the display label for a statistic type or custom label string.
"""
stat_label(x::Type{<:AbstractRegressionStatistic}) = label(x)
stat_label(x::Type{<:RegressionType}) = label(x)
stat_label(x::AbstractString) = x
stat_label(x) = string(x)

# Alignment conversion helper

"""Convert :l/:r/:c symbols to SummaryTables :left/:right/:center."""
_halign(s::Symbol) = s == :l ? :left : s == :r ? :right : s == :c ? :center : s

# Cell row builders for groups and extralines

function _to_cell_rows(data, ncols, halign, merge_cells)
    if data isa AbstractMatrix
        padded = add_blank(data, ncols)
        return [_values_to_cell_row(padded[i, :], halign, merge_cells) for i in 1:size(padded, 1)]
    elseif data isa AbstractVector
        if !isempty(data) && first(data) isa AbstractVector
            cell_rows = Vector{Cell}[]
            for v in data
                vals = collect(v)
                while length(vals) < ncols
                    pushfirst!(vals, "")
                end
                push!(cell_rows, _values_to_cell_row(vals, halign, merge_cells))
            end
            return cell_rows
        else
            vals = collect(data)
            while length(vals) < ncols
                pushfirst!(vals, "")
            end
            return [_values_to_cell_row(vals, halign, merge_cells)]
        end
    end
    Vector{Cell}[]
end

function _values_to_cell_row(vals, halign, merge_cells)
    cells = Cell[]
    for (i, v) in enumerate(vals)
        s = string(v)
        if i == 1
            push!(cells, Cell(isempty(s) ? nothing : s; halign=:left))
        elseif merge_cells && !isempty(s)
            push!(cells, Cell(s; merge=true, border_bottom=true, halign, bold=true))
        else
            push!(cells, Cell(isempty(s) ? nothing : s; halign))
        end
    end
    cells
end
