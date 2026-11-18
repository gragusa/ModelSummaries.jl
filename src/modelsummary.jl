
##############################################################################
## Default settings
##############################################################################

"""
    default_section_order()

Default section order for the table.
`:break` adds a visual gap between sections.
"""
function default_section_order()
    [:groups, :depvar, :estimator_names, :number_regressions, :break,
        :coef, :break, :fe, :break, :clusters,
        :break, :first_stage, :break, :regtype, :break, :controls,
        :break, :custom_lines, :stats, :extralines]
end

"""
    default_regression_statistics(rrs::Tuple)

Union, in order of first appearance, of the per-model
[`default_regression_statistics`](@ref) of the models in `rrs`.
"""
function default_regression_statistics(rrs::Tuple)
    unique(union(default_regression_statistics.(rrs)...))
end

# Escape helpers (for LaTeX label transforms)
const escape_latex_dict = Dict("&" => "\\&", "%" => "\\%", "\$" => "\\\$",
    "#" => "\\#", "_" => "\\_", "{" => "\\{", "}" => "\\}")

function _escape(s::Symbol)
    s == :ampersand ? Dict("&" => "\\&") :
    s == :underscore ? Dict("_" => "\\_") :
    s == :underscore2space ? Dict("_" => " ") :
    s == :latex ? escape_latex_dict :
    throw(ArgumentError("transform_labels = :$s is not recognized; use :ampersand, :underscore, :underscore2space, :latex, or a Dict"))
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
* `labels`: Dict mapping coefficient names to display labels. Keys are the names as
  `coefnames(model)` prints them, so an interaction is keyed `"x & z"` and a categorical level
  `"species: setosa"`.
* `interaction_separator`: String placed between the parts of an unlabeled interaction in the
  table (default `" × "`); `labels` keys always use `" & "`.
* `below_statistic`: Type shown below coefficients (`StdError`, `TStat`, `ConfInt`, or `nothing`).
* `regression_statistics`: Vector of statistic types for the bottom section. The default is
  the union of each model's [`ModelSummaries.default_regression_statistics`](@ref), e.g.
  `[Nobs, R2, R2McFadden]` for an OLS and a logit column. A cell is blank when the statistic
  does not apply to that column's model (see [`ModelSummaries.applies`](@ref)).
* `digits`, `digits_stats`: Number of decimal places.
* `stars`: Show significance stars (default `false`).
* `pvalue_note`: Append a note stating, per column, the distribution behind the p-values,
  e.g. `"p-values: (1) t(97); (2) Normal"` (default `false`). Throws for a model without a
  [`ModelSummaries.reference_distribution`](@ref) method, or whose `coeftable` p-values that
  distribution does not reproduce.

P-values (and stars), test statistics (`TStat`), and confidence intervals (`ConfInt`) are
read from each model's `coeftable` and `confint`; ModelSummaries computes no inference.
* `groups`: Group labels for columns.
* `estimator_names`: Vector of estimator labels for a header row (e.g., `["OLS", "IV", "OLS"]`).
* `yes_indicator`: String shown for active fixed effects (default `"Yes"`, use `"✓"` for checkmarks).
* `footnotes`: Vector of footnote strings or `SummaryTables.Concat` objects appended below the table.
* `custom_lines`: Vector of `Pair{String, Vector}` for custom rows (e.g., `["Sample" => ["Full", "Full"]]`).
* `keep`, `drop`, `order`, and `fixedeffects` throw an `ArgumentError` when a name or regex
  matches no coefficient (fixed effect) of any model, or when an index is out of range.
* `standardize_coef`: `true`, `false`, or one `Bool` per model. Throws an `ArgumentError` for a
  model whose coefficients cannot be standardized (see [`ModelSummaries.can_standardize`](@ref)).
* `file`: Save table to file. The extension determines the format: `.tex` (LaTeX),
  `.html`/`.htm` (HTML), `.typ` (Typst), or `.docx` (Word). Any other extension throws an
  `ArgumentError` before the table is built.
"""
function modelsummary(
        rrs::RegressionModel...;
        keep::Vector = Vector{Any}(),
        drop::Vector = Vector{Any}(),
        order::Vector = Vector{Any}(),
        fixedeffects::Vector = Vector{String}(),
        labels::Dict{String} = Dict{String, Any}(),
        interaction_separator::AbstractString = " \u00d7 ",
        align::Symbol = :r,
        header_align::Symbol = :c,
        below_statistic = StdError,
        regression_statistics = default_regression_statistics(rrs),
        groups = nothing,
        print_depvar::Bool = true,
        number_regressions::Bool = length(rrs) > 1,
        print_estimator_section = false,
        print_fe_section = true,
        print_first_stage_section = false,
        file = nothing,
        transform_labels::Union{Dict, Symbol} = Dict{String, Any}(),
        extralines = nothing,
        section_order = nothing,
        print_fe_suffix = true,
        print_control_indicator = true,
        standardize_coef = false,
        print_clusters = false,
        digits = nothing,
        digits_stats = nothing,
        use_relabeled_values = false,
        confint_level = 0.95,
        stars::Bool = false,
        pvalue_note::Bool = false,
        yes_indicator = "Yes",
        footnotes::Vector = [],
        estimator_names = nothing,
        custom_lines::Vector = [],
        depvar_bold::Bool = false
)
    nreg = length(rrs)
    ncols = 1 + nreg

    # Process arguments
    if section_order === nothing
        section_order = default_section_order()
    end

    align ∈ (:l, :r, :c) ||
        throw(ArgumentError("align = :$align is not recognized; use :l, :r, or :c"))
    header_align ∈ (:l, :r, :c) ||
        throw(ArgumentError("header_align = :$header_align is not recognized; use :l, :r, or :c"))
    file === nothing || output_mime(file)

    if isa(transform_labels, Symbol)
        transform_labels = _escape(transform_labels)
    end
    if isa(standardize_coef, Bool)
        standardize_coef = fill(standardize_coef, nreg)
    end
    length(standardize_coef) == nreg ||
        throw(ArgumentError("standardize_coef has $(length(standardize_coef)) entries for $nreg models"))
    if !isa(confint_level, AbstractVector)
        confint_level = fill(confint_level, nreg)
    end
    for (i, rr) in enumerate(rrs)
        if standardize_coef[i] && !can_standardize(rr)
            throw(ArgumentError("standardize_coef: the coefficients of model $i ($(typeof(rr))) cannot be standardized; define `ModelSummaries.can_standardize` and `ModelSummaries.standardize_coef_values` for this type, or pass `standardize_coef = false` for this model"))
        end
    end

    # Symbol aliases for below_statistic
    if isa(below_statistic, Symbol)
        below_statistic = below_statistic == :se ? StdError :
                          below_statistic == :tstat ? TStat :
                          below_statistic == :none ? nothing :
                          throw(ArgumentError("below_statistic = :$below_statistic is not recognized; use :se, :tstat, :none, or a statistic type"))
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

    check_selectors(nms, keep, "keep")
    check_selectors(nms, drop, "drop")
    check_selectors(nms, order, "order")
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
                    Cell(display_name(y, interaction_separator);
                        merge = true, bold = depvar_bold, border_bottom = true, halign = hdr_halign))
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
                row = Cell[Cell(display_name(nms[j], interaction_separator); halign = :left)]
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
                if below_statistic !== nothing
                    brow = Cell[Cell(nothing; halign = :left)]
                    for i in 1:nreg
                        push!(brow,
                            make_understat_cell(coefbelow[j, i];
                                digits = below_digits, stars, halign = body_halign))
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
                    push!(row, make_stat_cell(sv;
                        digits = stat_digits, stars, halign = body_halign))
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
                    push!(row, Cell(string(val); halign = :center))
                end
                # Pad if fewer values than models
                for _ in (length(lvals) + 1):nreg
                    push!(row, Cell(nothing; halign = :center))
                end
                push!(rows, row)
            end

        elseif v isa Symbol
            # Handle :fe, :clusters, :first_stage via other_stats
            temp = [other_stats(t, v) for t in rrs]
            if all(isnothing, temp)
                continue
            end
            i_first = findfirst(!isnothing, temp)
            fill_val = fill_missing(last(first(temp[i_first])))
            # `fixedeffects` selects fixed-effect names only; other sections show every name.
            st = combine_other_statistics(
                temp; fill_val, print_fe_suffix,
                fixedeffects = v == :fe ? fixedeffects : String[], labels,
                transform_labels, yes_indicator)
            if st !== nothing
                for j in 1:size(st, 1)
                    row = Cell[Cell(string(st[j, 1]); halign = :left)]
                    for i in 1:nreg
                        val = st[j, i + 1]
                        push!(row, Cell(format_other_stat(val; digits = stat_digits);
                            halign = :center))
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

    if pvalue_note
        footnotes = [footnotes; pvalue_note_text(rrs)]
    end

    table = Table(cells;
        header = header_end > 0 ? header_end : nothing,
        rowgaps = rgaps,
        round_mode = nothing,   # we handle rounding ourselves
        footnotes = footnotes
    )

    file === nothing || write_table(file, table)

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
            mat[j, i] = applies(s, t) ? s(t) : nothing
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
        labels = Dict{String, Any}(),
        transform_labels = Dict{String, Any}(),
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
    check_selectors(nms, fixedeffects, "fixedeffects")
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
    check_selectors(nms, selectors, kw)

Throw an `ArgumentError` if a `String` or `Regex` in `selectors` matches no element of `nms`,
the full list of names before any filtering. `kw` names the keyword in the message.
"""
function check_selectors(nms, selectors, kw)
    names = string.(nms)
    for x in selectors
        found = x isa String ? x in names :
                x isa Regex ? any(n -> occursin(x, n), names) : true
        found ||
            throw(ArgumentError("$kw: $(repr(x)) matches no name; available names: $(join(repr.(names), ", "))"))
    end
end

"""
    value_pos(nms, x)

Returns the position(s) of `x` in the vector `nms`. A name absent from `nms` gives no
positions: [`check_selectors`](@ref) has already rejected names absent from every model, and
an earlier `keep` or `drop` may have removed the rest.
"""
value_pos(nms, x::String) = findall(==(x), string.(nms))

function value_pos(nms, x::Int)
    x in eachindex(nms) ||
        throw(ArgumentError("index $x is out of range for $(length(nms)) names"))
    x:x
end

function value_pos(nms, x::UnitRange)
    issubset(x, eachindex(nms)) ||
        throw(ArgumentError("index range $x is out of range for $(length(nms)) names"))
    x
end

value_pos(nms, x::BitVector) = findall(x)
value_pos(nms, x::Regex) = findall(n -> occursin(x, n), string.(nms))

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

##############################################################################
## File output
##############################################################################

const FILE_FORMATS = (".tex" => MIME"text/latex"(), ".html" => MIME"text/html"(),
    ".htm" => MIME"text/html"(), ".typ" => MIME"text/typst"(), ".docx" => :docx)

"""
    output_mime(file)

The output format for `file`, chosen by its extension (case-insensitive). Throws an
`ArgumentError` for an unsupported extension.
"""
function output_mime(file)
    ext = lowercase(splitext(file)[2])
    for (e, m) in FILE_FORMATS
        e == ext && return m
    end
    throw(ArgumentError("file = $(repr(file)): unsupported extension $(repr(ext)); use one of $(join(first.(FILE_FORMATS), ", "))"))
end

"""
    write_table(file, table::Table)

Write `table` to `file` in the format given by the file's extension (see [`output_mime`](@ref)).
"""
function write_table(file, table::Table)
    m = output_mime(file)
    if m === :docx
        doc = WriteDocx.Document(WriteDocx.Body([WriteDocx.Section([SummaryTables.to_docx(table)])]))
        WriteDocx.save(file, doc)
    else
        open(io -> show(io, m, table), file, "w")
    end
    file
end
