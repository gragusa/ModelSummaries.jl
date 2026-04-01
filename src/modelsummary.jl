
##############################################################################
## Default settings (no render type parameter)
##############################################################################

default_digits(x) = 3
default_digits(x::AbstractRegressionStatistic) = default_digits(value(x))
default_digits(x::AbstractUnderStatistic) = default_digits(value(x))
default_digits(x::CoefValue) = default_digits(value(x))

"""
    default_section_order()

Default section order for the table.
`:break` adds a visual gap between sections.
"""
function default_section_order()
    [:groups, :depvar, :estimator_names, :number_regressions, :break,
        :coef, :break, :fe, :break, :randomeffects, :break, :clusters,
        :break, :first_stage, :break, :regtype, :break, :controls,
        :break, :custom_lines, :stats, :extralines]
end

default_depvar() = true
default_number_regressions(rrs) = length(rrs) > 1
default_print_fe(rrs) = true
default_print_randomeffects(rrs) = true
default_groups(rrs) = nothing
default_extralines(rrs) = nothing
default_keep(rrs) = Vector{String}()
default_drop(rrs) = Vector{String}()
default_order(rrs) = Vector{String}()
default_fixedeffects(rrs) = Vector{String}()
default_labels(rrs) = Dict{String, String}()
default_below_statistic() = StdError
default_stat_below() = true
default_align() = :r
default_header_align() = :c
default_file(rrs) = nothing
default_print_fe_suffix() = true
default_print_control_indicator() = true
default_standardize_coef(rrs) = false

"""
    default_transform_labels(rrs)

Default label transformation. Returns empty dict (no transformation).
"""
default_transform_labels(rrs) = Dict{String, String}()

default_print_estimator(rrs) = length(unique(RegressionType.(rrs))) > 1
default_print_clusters(rrs) = false

function default_regression_statistics(rrs::Tuple)
    unique(union(default_regression_statistics.(rrs)...))
end

default_confint_level() = 0.95
default_use_relabeled_values(rrs) = true

# Escape helpers (for LaTeX label transforms)
const escape_latex_dict = Dict("&" => "\\&", "%" => "\\%", "\$" => "\\\$",
    "#" => "\\#", "_" => "\\_", "{" => "\\{", "}" => "\\}")

function _escape(s::Symbol)
    s == :ampersand ? Dict("&" => "\\&") :
    s == :underscore ? Dict("_" => "\\_") :
    s == :underscore2space ? Dict("_" => " ") :
    s == :latex ? escape_latex_dict :
    error("Please provide :ampersand, :underscore, :underscore2space, :latex, or a Dict.")
end

##############################################################################
## Main function
##############################################################################

"""
    modelsummary(rr::RegressionModel...; kwargs...)

Produces a publication-quality regression table using SummaryTables.jl.
Returns a `SummaryTables.Table` object that renders natively to HTML, LaTeX, and Typst.

### Key Arguments
* `rr::RegressionModel...`: Regression models to display.
* `keep`, `drop`, `order`: Filter and reorder coefficients.
* `fixedeffects`: Filter fixed effects.
* `labels`: Dict mapping variable names to display labels.
* `below_statistic`: Type shown below coefficients (`StdError`, `TStat`, `ConfInt`, or `nothing`).
* `regression_statistics`: Vector of statistic types for the bottom section.
* `digits`, `digits_stats`: Number of decimal places.
* `stars`: Show significance stars (default `false`).
* `groups`: Group labels for columns.
* `estimator_names`: Vector of estimator labels for a header row (e.g., `["OLS", "IV", "OLS"]`).
* `yes_indicator`: String shown for active fixed effects (default `"Yes"`, use `"✓"` for checkmarks).
* `footnotes`: Vector of footnote strings or `SummaryTables.Concat` objects appended below the table.
* `custom_lines`: Vector of `Pair{String, Vector}` for custom rows (e.g., `["Sample" => ["Full", "Full"]]`).
* `file`: Save table to file (extension determines format: .tex, .html, .typ).
"""
function modelsummary(
        rrs::RegressionModel...;
        keep::Vector = Vector{Any}(),
        drop::Vector = Vector{Any}(),
        order::Vector = Vector{Any}(),
        fixedeffects::Vector = Vector{String}(),
        labels::Dict{String, String} = Dict{String, String}(),
        align::Symbol = :r,
        header_align::Symbol = :c,
        below_statistic = StdError,
        stat_below::Bool = true,
        regression_statistics = [Nobs, R2],
        groups = nothing,
        print_depvar::Bool = true,
        number_regressions::Bool = length(rrs) > 1,
        print_estimator_section = false,
        print_fe_section = true,
        print_first_stage_section = false,
        file = nothing,
        transform_labels::Union{Dict, Symbol} = Dict{String, String}(),
        extralines = nothing,
        section_order = nothing,
        print_fe_suffix = true,
        print_control_indicator = true,
        standardize_coef = false,
        print_clusters = false,
        print_randomeffects = false,
        digits = nothing,
        digits_stats = nothing,
        use_relabeled_values = false,
        confint_level = 0.95,
        stars::Bool = false,
        yes_indicator::AbstractString = "Yes",
        footnotes::Vector = [],
        estimator_names = nothing,
        custom_lines::Vector = []
)
    nreg = length(rrs)
    ncols = 1 + nreg

    # Process arguments
    if section_order === nothing
        section_order = default_section_order()
    end

    @assert align ∈ (:l, :r, :c) "align must be one of :l, :r, :c"
    @assert header_align ∈ (:l, :r, :c) "header_align must be one of :l, :r, :c"

    if isa(transform_labels, Symbol)
        transform_labels = _escape(transform_labels)
    end
    if isa(standardize_coef, Bool)
        standardize_coef = fill(standardize_coef, nreg)
    end
    if !isa(confint_level, AbstractVector)
        confint_level = fill(confint_level, nreg)
    end
    for (i, rr) in enumerate(rrs)
        standardize_coef[i] = standardize_coef[i] && can_standardize(rr)
    end

    # Symbol aliases for below_statistic
    if isa(below_statistic, Symbol)
        below_statistic = below_statistic == :se ? StdError :
                          below_statistic == :tstat ? TStat :
                          below_statistic == :none ? nothing :
                          error("unrecognized below_statistic")
    end

    # Symbol aliases for regression_statistics
    regression_statistics = replace(
        regression_statistics,
        :nobs => Nobs, :r2 => R2, :adjr2 => AdjR2,
        :r2_within => R2Within, :f => FStat, :p => FStatPValue,
        :f_kp => FStatIV, :p_kp => FStatIVPValue, :dof => DOF
    )

    body_halign = _halign(align)
    hdr_halign = _halign(header_align)

    ##########################################################################
    # Collect coefficient names
    ##########################################################################

    nms = if use_relabeled_values
        union([replace_name.(_coefnames(rr), Ref(labels), Ref(transform_labels))
               for rr in rrs]...) |> unique
    else
        union([_coefnames(rr) for rr in rrs]...) |> unique
    end

    if length(keep) > 0
        nms = build_nm_list(nms, keep)
    end
    if length(drop) > 0
        drop_names!(nms, drop)
    end
    if length(order) > 0
        nms = reorder_nms_list(nms, order)
    end
    if !use_relabeled_values
        nms = replace_name.(nms, Ref(labels), Ref(transform_labels)) |> unique
    end

    ##########################################################################
    # Build coefficient value and under-statistic matrices
    ##########################################################################

    coefvalues = Matrix{Any}(missing, length(nms), nreg)
    coefbelow = Matrix{Any}(missing, length(nms), nreg)
    for (i, rr) in enumerate(rrs)
        cur_nms = replace_name.(_coefnames(rr), Ref(labels), Ref(transform_labels))
        for (j, nm) in enumerate(nms)
            k = findfirst(cur_nms .== nm)
            k === nothing && continue
            coefvalues[j, i] = CoefValue(rr, k; standardize = standardize_coef[i])
            if below_statistic !== nothing
                coefbelow[j, i] = below_statistic(
                    rr, k; standardize = standardize_coef[i], level = confint_level[i])
            end
        end
    end

    ##########################################################################
    # Build active sections list
    ##########################################################################

    sections = []
    for (idx, s) in enumerate(section_order)
        if s == :depvar
            print_depvar && push!(sections, :depvar)
        elseif s == :groups
            groups !== nothing && push!(sections, groups)
        elseif s == :number_regressions
            number_regressions && push!(sections, :number_regressions)
        elseif s == :estimator_names
            estimator_names !== nothing && push!(sections, :estimator_names)
        elseif s == :regtype
            print_estimator_section && push!(sections, :regtype)
        elseif s == :custom_lines
            !isempty(custom_lines) && push!(sections, :custom_lines)
        elseif s == :fe
            print_fe_section && push!(sections, :fe)
        elseif s == :extralines
            extralines !== nothing && push!(sections, extralines)
        elseif s == :break
            if idx == 1
                push!(sections, :break)
            elseif !isempty(sections) && last(sections) != :break
                push!(sections, :break)
            end
        elseif s == :controls
            print_control_indicator && push!(sections, :controls)
        elseif s == :clusters
            print_clusters && push!(sections, :clusters)
        elseif s == :first_stage
            print_first_stage_section && push!(sections, :first_stage)
        elseif s == :randomeffects
            print_randomeffects && push!(sections, :randomeffects)
        else
            push!(sections, s)
        end
    end
    if !isempty(sections) && last(sections) == :break && last(section_order) != :break
        pop!(sections)
    end

    ##########################################################################
    # Build table rows
    ##########################################################################

    rows = Vector{Cell}[]
    rowgap_after = Set{Int}()
    header_end = 0
    in_header = true

    coef_digits = digits === nothing ? 3 : digits
    below_digits = digits_stats !== nothing ? digits_stats : coef_digits
    stat_digits = digits_stats !== nothing ? digits_stats :
                  (digits !== nothing ? digits : 3)

    for s in sections
        # Handle Pair sections (custom label + section)
        v = s
        if s isa Pair
            label_text = string(last(s))
            row = Cell[Cell(label_text; halign = :left)]
            for _ in 1:nreg
                push!(row, Cell(nothing; halign = body_halign))
            end
            push!(rows, row)
            v = first(s)
        end

        if v == :break
            !isempty(rows) && push!(rowgap_after, length(rows))

        elseif v == :depvar
            y_names = replace_name.(_responsename.(rrs), Ref(labels), Ref(transform_labels))
            row = Cell[Cell(nothing; halign = :left)]
            for y in y_names
                push!(row,
                    Cell(display_name(y);
                        merge = true, bold = true, border_bottom = true, halign = hdr_halign))
            end
            push!(rows, row)

        elseif v == :estimator_names
            row = Cell[Cell(nothing; halign = :left)]
            for (i, nm) in enumerate(estimator_names)
                push!(row, Cell(string(nm); halign = hdr_halign, merge = true))
            end
            push!(rows, row)

        elseif v == :number_regressions
            row = Cell[Cell(nothing; halign = :left)]
            for i in 1:nreg
                push!(row, Cell("($i)"; halign = hdr_halign))
            end
            push!(rows, row)

        elseif v == :coef
            in_header = false
            header_end = length(rows)

            for j in 1:length(nms)
                # Coefficient value row
                row = Cell[Cell(display_name(nms[j]); halign = :left)]
                for i in 1:nreg
                    cv = coefvalues[j, i]
                    if ismissing(cv)
                        push!(row, Cell(nothing; halign = body_halign))
                    else
                        push!(row, make_coef_cell(cv;
                            digits = coef_digits, stars, halign = body_halign))
                    end
                end
                push!(rows, row)

                # Below-statistic row
                if below_statistic !== nothing && stat_below
                    brow = Cell[Cell(nothing; halign = :left)]
                    for i in 1:nreg
                        push!(brow,
                            make_understat_cell(coefbelow[j, i];
                                digits = below_digits, halign = body_halign))
                    end
                    push!(rows, brow)
                end
            end

        elseif v == :regtype
            row = Cell[Cell(label(RegressionType); halign = :left)]
            for rr in rrs
                rt = RegressionType(rr)
                push!(row, Cell(display_regtype(rt); halign = body_halign))
            end
            push!(rows, row)

        elseif v == :stats
            stats_mat = combine_statistics(rrs, regression_statistics)
            for j in 1:size(stats_mat, 1)
                row = Cell[Cell(stat_label(stats_mat[j, 1]); halign = :left)]
                for i in 1:nreg
                    sv = stats_mat[j, i + 1]
                    push!(row, Cell(format_stat_value(sv; digits = stat_digits);
                        halign = body_halign))
                end
                push!(rows, row)
            end

        elseif v == :controls
            ctrl = missing_vars.(rrs, Ref(string.(nms)); labels, transform_labels)
            if any(ctrl)
                row = Cell[Cell(label(HasControls); halign = :left)]
                for val in ctrl
                    push!(row, Cell(val ? yes_indicator : ""; halign = body_halign))
                end
                push!(rows, row)
            end

        elseif v == :custom_lines
            for line in custom_lines
                lname = first(line)
                lvals = last(line)
                row = Cell[Cell(string(lname); halign = :left)]
                for (i, val) in enumerate(lvals)
                    push!(row, Cell(string(val); halign = body_halign))
                end
                # Pad if fewer values than models
                for _ in (length(lvals) + 1):nreg
                    push!(row, Cell(nothing; halign = body_halign))
                end
                push!(rows, row)
            end

        elseif v isa Symbol
            # Handle :fe, :clusters, :first_stage, :randomeffects via other_stats
            temp = [other_stats(t, v) for t in rrs]
            if all(isnothing, temp)
                continue
            end
            i_first = findfirst(!isnothing, temp)
            fill_val = fill_missing(last(first(temp[i_first])))
            st = combine_other_statistics(
                temp; fill_val, print_fe_suffix, fixedeffects, labels,
                transform_labels, yes_indicator)
            if st !== nothing
                for j in 1:size(st, 1)
                    row = Cell[Cell(string(st[j, 1]); halign = :left)]
                    for i in 1:nreg
                        val = st[j, i + 1]
                        push!(row, Cell(format_other_stat(val; digits = stat_digits);
                            halign = body_halign))
                    end
                    push!(rows, row)
                end
            end

        else
            # Non-symbol sections: groups or extralines data
            cell_rows = _to_cell_rows(v, ncols, in_header ? hdr_halign : body_halign, in_header)
            append!(rows, cell_rows)
        end
    end

    ##########################################################################
    # Assemble table
    ##########################################################################

    nrow = length(rows)
    cells = Matrix{Cell}(undef, nrow, ncols)
    for i in 1:nrow
        for j in 1:min(length(rows[i]), ncols)
            cells[i, j] = rows[i][j]
        end
        for j in (length(rows[i]) + 1):ncols
            cells[i, j] = Cell(nothing)
        end
    end

    rgaps = Pair{Int, Float64}[p => 8.0
                               for p in sort(collect(rowgap_after))
                               if 0 < p < nrow]

    table = Table(cells;
        header = header_end > 0 ? header_end : nothing,
        rowgaps = rgaps,
        round_mode = nothing,   # we handle rounding ourselves
        footnotes = footnotes
    )

    if file !== nothing
        open(file, "w") do io
            ext = lowercase(splitext(file)[2])
            if ext == ".tex"
                show(io, MIME"text/latex"(), table)
            elseif ext in (".html", ".htm")
                show(io, MIME"text/html"(), table)
            elseif ext == ".typ"
                show(io, MIME"text/typst"(), table)
            else
                show(io, MIME"text/html"(), table)
            end
        end
    end

    table
end

##############################################################################
## Helper functions (kept from original)
##############################################################################

display_val(x::Pair) = last(x)
display_val(x::Type) = x
f_val(x::Pair) = first(x)
f_val(x::Type) = x

"""
    combine_statistics(tables, stats)

Takes a set of tables (RegressionModels) and a vector of statistic types.
"""
function combine_statistics(tables, stats)
    types_strings = display_val.(stats)
    type_f = f_val.(stats)
    mat = Matrix{Any}(missing, length(types_strings), length(tables))
    for (i, t) in enumerate(tables)
        for (j, s) in enumerate(type_f)
            mat[j, i] = s(t)
        end
    end
    hcat(types_strings, mat)
end

"""
    combine_other_statistics(stats; kwargs...)

Takes vector of nothing or statistics and combines these into a single section.
"""
function combine_other_statistics(
        stats;
        fill_val = missing,
        print_fe_suffix = true,
        fixedeffects = Vector{String}(),
        labels = Dict{String, String}(),
        transform_labels = Dict{String, String}(),
        yes_indicator = "Yes",
        kwargs...
)
    nms = []
    for s in stats
        if !isnothing(s)
            for f in first.(s)
                if !(string(f) in string.(nms))
                    push!(nms, f)
                end
            end
        end
    end
    if length(nms) == 0
        return nothing
    end
    nms = replace_name.(nms, Ref(labels), Ref(transform_labels))
    if length(fixedeffects) > 0
        nms = build_nm_list(nms, fixedeffects)
    end
    mat = Matrix{Union{Missing, Any}}(missing, length(nms), length(stats))
    for (i, s) in enumerate(stats)
        if isnothing(s)
            if fill_val isa FixedEffectValue
                mat[:, i] .= fill_val.val ? yes_indicator : ""
            else
                mat[:, i] .= fill_val
            end
            continue
        end
        val_nms = first.(s)
        val_nms = replace_name.(val_nms, Ref(labels), Ref(transform_labels))
        for (j, nm) in enumerate(nms)
            k = findfirst(string(nm) .== string.(val_nms))
            if k === nothing
                if fill_val isa FixedEffectValue
                    mat[j, i] = fill_val.val ? yes_indicator : ""
                else
                    mat[j, i] = fill_val
                end
            else
                val = last(s[k])
                if val isa FixedEffectValue
                    mat[j, i] = val.val ? yes_indicator : ""
                else
                    mat[j, i] = val
                end
            end
        end
    end

    # Format names with appropriate suffixes
    if print_fe_suffix
        nms = map(nms) do n
            base_name = uppercasefirst(string(value(n)))
            if n isa FixedEffectCoefName
                base_name * fe_suffix()
            elseif n isa ClusterCoefName
                base_name * cluster_suffix()
            elseif n isa FirstStageCoefName
                base_name * first_stage_suffix()
            else
                base_name * fe_suffix()
            end
        end
    else
        nms = value.(nms)
    end

    hcat(nms, mat)
end

"""
    value_pos(nms, x)

Returns the position(s) of `x` in the vector `nms`.
"""
value_pos(nms, x::String) = value_pos(nms, findfirst(string.(nms) .== x))

function value_pos(nms, x::Int)
    @assert x in eachindex(nms) "x must be a valid index for the coefficient names"
    x:x
end

function value_pos(nms, x::UnitRange)
    @assert all(i in eachindex(nms) for i in x) "x must be a valid index range"
    x
end

value_pos(nms, x::BitVector) = findall(x)
value_pos(nms, x::Regex) = value_pos(nms, occursin.(x, string.(nms)))
value_pos(nms, x::Nothing) = Int[]

function value_pos(nms, x::Symbol)
    if x == :last || x == :end
        value_pos(nms, length(nms))
    else
        throw(ArgumentError("Symbol $x not recognized"))
    end
end

function value_pos(nms, x::Tuple{Symbol, Int})
    if x[1] == :last
        value_pos(nms, (length(nms) - x[2] + 1):length(nms))
    elseif x[1] == :end
        value_pos(nms, length(nms) - x[2])
    else
        throw(ArgumentError("Symbol $(x[1]) not recognized"))
    end
end

"""
    reorder_nms_list(nms, order)

Reorders `nms` according to `order`, keeping all elements.
"""
function reorder_nms_list(nms, order)
    out = Int[]
    for o in order
        x = value_pos(nms, o)
        for i in x
            if i ∉ out
                push!(out, i)
            end
        end
    end
    for i in 1:length(nms)
        if i ∉ out
            push!(out, i)
        end
    end
    nms[out]
end

"""
    build_nm_list(nms, keep)

Returns the subset of `nms` matching `keep`, in `keep` order.
"""
function build_nm_list(nms, keep)
    out = Int[]
    for k in keep
        x = value_pos(nms, k)
        for i in x
            if i ∉ out
                push!(out, i)
            end
        end
    end
    nms[out]
end

"""
    drop_names!(nms, to_drop)

Drops elements of `nms` matching `to_drop`.
"""
function drop_names!(nms, to_drop)
    out = Int[]
    for o in to_drop
        x = value_pos(nms, o)
        for i in x
            if i ∉ out
                push!(out, i)
            end
        end
    end
    deleteat!(nms, out)
end

"""
    missing_vars(table::RegressionModel, coefs::Vector; labels, transform_labels)

Returns `true` if any coefficient in `table` is not in `coefs`.
"""
function missing_vars(table::RegressionModel, coefs::Vector;
        labels = Dict(), transform_labels = Dict())
    table_coefs = string.(replace_name.(_coefnames(table), Ref(labels), Ref(transform_labels)))
    coefs = string.(coefs)
    for x in table_coefs
        if x ∉ coefs
            return true
        end
    end
    false
end

"""
    add_blank(groups::Matrix, n)

Pads `groups` to at least `n` columns by prepending blank columns.
"""
function add_blank(groups::Matrix, n)
    if size(groups, 2) < n
        groups = hcat(fill("", size(groups, 1)), groups)
        add_blank(groups, n)
    else
        groups
    end
end
function add_blank(groups::Vector{Vector}, n)
    out = Vector{Vector}()
    for g in groups
        if length(g) < n
            g = vcat(fill("", n - length(g)), g)
        end
        push!(out, g)
    end
    groups
end
