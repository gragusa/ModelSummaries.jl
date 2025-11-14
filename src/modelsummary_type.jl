"""
    mutable struct ModelSummary
        data::Matrix{Any}
        header::Vector{Vector{String}}
        header_align::Vector{Symbol}
        body_align::Vector{Symbol}
        hlines::Vector{Int}
        formatters::Vector
        highlighters::Vector
        backend::Union{Symbol, Nothing}
        pretty_kwargs::Dict{Symbol, Any}
        table_format::Dict{Symbol, Any}  # Can hold LatexTableFormat, MarkdownTableFormat, or HtmlTableFormat
    end

A container for regression table data that uses PrettyTables.jl for rendering.

# Fields
- `data`: Matrix of table data (both header and body combined)
- `header`: Vector of header rows (for multi-level headers)
- `header_align`: Alignment for header columns (:l, :c, :r)
- `body_align`: Alignment for body columns (:l, :c, :r)
- `hlines`: Positions of horizontal lines (row indices)
- `formatters`: Vector of PrettyTables formatters
- `highlighters`: Vector of PrettyTables highlighters
- `backend`: Rendering backend (:text, :ascii, :markdown, :html, :latex, or nothing for auto-detection)
- `pretty_kwargs`: Additional keyword arguments to pass to PrettyTables.pretty_table
- `table_format`: Mapping of backend ⇒ table format objects (LatexTableFormat, MarkdownTableFormat, HtmlTableFormat) used by `_render_table`

# Display
The table automatically selects the appropriate backend based on MIME type:
- Terminal/REPL: Markdown backend (text)
- Jupyter/HTML context: HTML backend
- LaTeX context: LaTeX backend

You can override the backend using `set_backend!` or by setting the `backend` field directly.

# Customization
After creating a table, you can customize it using:
- `add_hline!`: Add horizontal lines
- `set_alignment!`: Change column alignment
- `add_formatter!`: Add custom formatters
- `set_backend!`: Change the rendering backend
- `merge_kwargs!`: Add arbitrary PrettyTables.jl options

# Examples
```julia
julia> rt = modelsummary(model1, model2)  # Creates a ModelSummary

julia> add_hline!(rt, 5)  # Add horizontal line after row 5

julia> set_backend!(rt, :latex)  # Force LaTeX backend

julia> merge_kwargs!(rt; title="My Regression Results")  # Add PrettyTables options
```
"""
mutable struct ModelSummary
    data::Matrix{Any}
    header::Vector{Vector{String}}
    header_align::Vector{Symbol}
    body_align::Vector{Symbol}
    hlines::Vector{Int}
    formatters::Vector
    highlighters::Vector
    backend::Union{Symbol, Nothing}
    pretty_kwargs::Dict{Symbol, Any}
    table_format::Dict{Symbol, Any}

    function ModelSummary(
        data::Matrix{Any},
        header::Vector{Vector{String}},
        header_align::Vector{Symbol},
        body_align::Vector{Symbol};
        hlines::Vector{Int}=Int[],
        formatters::Vector=[],
        highlighters::Vector=[],
        backend::Union{Symbol, Nothing}=nothing,
        pretty_kwargs::Dict{Symbol, Any}=Dict{Symbol, Any}(),
        table_format=nothing
    )
        tf_map = _normalize_table_format(table_format)
        new(
            data,
            header,
            header_align,
            body_align,
            hlines,
            formatters,
            highlighters,
            backend,
            pretty_kwargs,
            tf_map,
        )
    end
end

const _MODEL_SUMMARIES_BACKENDS = (:text, :ascii, :markdown, :html, :latex)

"""
    _ascii_table_format()

Create a TextTableFormat using only ASCII characters (no Unicode box-drawing).
Uses '+' for corners/intersections, '|' for vertical lines, and '-' for horizontal lines.
"""
function _ascii_table_format()
    ascii_borders = PrettyTables.TextTableBorders(
        '+', '+', '+', '+',  # top-right, top-left, bottom-left, bottom-right
        '+', '+', '+', '+', '+',  # down, right, left, cross, up
        '|', '-'  # vertical, horizontal
    )
    return PrettyTables.TextTableFormat(; borders=ascii_borders)
end

"""
    default_table_format(backend::Symbol)

Return the default table format for the given backend when no explicit
`table_format` is provided. Supported backends are `:text`, `:ascii`, `:markdown`, `:html`, and `:latex`.

Note: PrettyTables 3.x uses backend-specific format types:
- LatexTableFormat for LaTeX
- MarkdownTableFormat for Markdown
- HtmlTableFormat for HTML
- Text backend: Uses default TextTableFormat (Unicode box-drawing)
- ASCII backend: Uses TextTableFormat with ASCII-only characters

In ModelSummaries.jl:
- :text backend uses the PrettyTables text backend with Unicode box-drawing
- :ascii backend uses the PrettyTables text backend with ASCII-only characters
- :markdown backend uses MarkdownTableFormat
"""
function default_table_format(backend::Symbol)
    if backend == :text
        # Text backend uses default TextTableFormat (Unicode)
        return nothing
    elseif backend == :ascii
        # ASCII backend uses custom ASCII-only format
        return _ascii_table_format()
    elseif backend == :markdown
        return PrettyTables.MarkdownTableFormat()
    elseif backend == :html
        return PrettyTables.HtmlTableFormat()
    elseif backend == :latex
        return PrettyTables.latex_table_format__booktabs
    else
        throw(ArgumentError("Unsupported backend $backend. Valid options are :text, :ascii, :markdown, :html, or :latex."))
    end
end

"""
    default_table_formats()

Construct a dictionary with the default table format for every backend.
"""
function default_table_formats()
    formats = Dict{Symbol, Any}()
    for backend in _MODEL_SUMMARIES_BACKENDS
        formats[backend] = default_table_format(backend)
    end
    formats
end

function _table_format_from_symbol(sym::Symbol)
    # In PrettyTables 3.x, there are no unified tf_* constants
    # Only a few specific constants exist like latex_table_format__booktabs
    candidates = [
        Symbol("latex_table_format__$(sym)"),
        Symbol("text_table_format__$(sym)"),
        Symbol("markdown_table_format__$(sym)"),
        Symbol("html_table_format__$(sym)")
    ]

    for candidate in candidates
        if isdefined(PrettyTables, candidate)
            return getproperty(PrettyTables, candidate)
        end
    end
    throw(ArgumentError("Unknown table_format alias :$sym. In PrettyTables 3.x, use format constructors directly (e.g., LatexTableFormat(), MarkdownTableFormat()) or specific constants like :booktabs."))
end

function _coerce_table_format_value(val, backend::Symbol)
    if val === nothing || val === :default
        return default_table_format(backend)
    elseif val isa Union{PrettyTables.LatexTableFormat, PrettyTables.MarkdownTableFormat, PrettyTables.HtmlTableFormat}
        return val
    elseif val isa Symbol
        # Try to resolve known symbols
        if val == :booktabs && backend == :latex
            return PrettyTables.latex_table_format__booktabs
        else
            return _table_format_from_symbol(val)
        end
    else
        throw(ArgumentError("table_format entries must be table format objects (LatexTableFormat, MarkdownTableFormat, HtmlTableFormat), `:default`, or a supported alias symbol."))
    end
end

"""
    _normalize_table_format(spec)

Normalize user input into a backend ⇒ table format dictionary.
Accepts `nothing`, a table format object, an alias `Symbol`, `NamedTuple`, or any `AbstractDict`.
"""
function _normalize_table_format(spec)
    if spec === nothing
        return default_table_formats()
    elseif spec isa NamedTuple
        return _normalize_table_format(Dict(spec))
    elseif spec isa Pair
        return _normalize_table_format(Dict(spec))
    elseif spec isa AbstractDict
        formats = default_table_formats()
        for (k, v) in spec
            backend = Symbol(k)
            backend in _MODEL_SUMMARIES_BACKENDS || throw(ArgumentError("Unsupported backend $backend in table_format keyword."))
            formats[backend] = _coerce_table_format_value(v, backend)
        end
        return formats
    else
        formats = Dict{Symbol, Any}()
        for backend in _MODEL_SUMMARIES_BACKENDS
            formats[backend] = _coerce_table_format_value(spec, backend)
        end
        return formats
    end
end

# Convenience constructor for simple matrices
function ModelSummary(
    header::Vector{String},
    body::Matrix{Any};
    header_align::Union{Vector{Symbol}, Nothing}=nothing,
    body_align::Union{Vector{Symbol}, Nothing}=nothing,
    table_format=nothing,
    kwargs...
)
    ncols = length(header)
    @assert size(body, 2) == ncols "Header and body must have same number of columns"

    # Default alignments: left for first column, right for others
    if header_align === nothing
        header_align = [:l; fill(:c, ncols - 1)]
    end
    if body_align === nothing
        body_align = [:l; fill(:r, ncols - 1)]
    end

    ModelSummary(
        body,
        [header],
        header_align,
        body_align;
        table_format=table_format,
        kwargs...
    )
end

"""
    add_hline!(rt::ModelSummary, position::Int)

Add a horizontal line after the specified row position.
Row numbering includes header rows.
"""
function add_hline!(rt::ModelSummary, position::Int)
    if position ∉ rt.hlines
        push!(rt.hlines, position)
        sort!(rt.hlines)
    end
    rt
end

"""
    remove_hline!(rt::ModelSummary, position::Int)

Remove a horizontal line at the specified row position.
"""
function remove_hline!(rt::ModelSummary, position::Int)
    filter!(x -> x != position, rt.hlines)
    rt
end

"""
    set_alignment!(rt::ModelSummary, col::Int, align::Symbol; header::Bool=false)

Set the alignment for a specific column.
Set `header=true` to change header alignment instead of body alignment.
"""
function set_alignment!(rt::ModelSummary, col::Int, align::Symbol; header::Bool=false)
    @assert align in (:l, :c, :r) "Alignment must be :l, :c, or :r"
    if header
        rt.header_align[col] = align
    else
        rt.body_align[col] = align
    end
    rt
end

"""
    add_formatter!(rt::ModelSummary, f)

Add a PrettyTables formatter to the table.
See PrettyTables.jl documentation for formatter syntax.
"""
function add_formatter!(rt::ModelSummary, f)
    push!(rt.formatters, f)
    rt
end

"""
    set_backend!(rt::ModelSummary, backend::Symbol)

Set the rendering backend.
Valid backends: :text, :ascii, :markdown, :html, :latex, or :auto (nothing) for automatic detection.

Note: :text backend uses PrettyTables text backend (customization via kwargs),
:ascii backend is like :text but forces ASCII-only characters,
while :markdown uses markdown backend with MarkdownTableFormat.
"""
function set_backend!(rt::ModelSummary, backend::Union{Symbol, Nothing})
    if backend !== nothing
        @assert backend in (:text, :ascii, :markdown, :html, :latex) "Backend must be :text, :ascii, :markdown, :html, :latex, or nothing"
    end
    rt.backend = backend
    rt
end

"""
    merge_kwargs!(rt::ModelSummary; kwargs...)

Merge additional keyword arguments to pass to PrettyTables.pretty_table.
This allows you to use any PrettyTables.jl option for customization.

# Examples
```julia
merge_kwargs!(rt; title="My Results", title_alignment=:c)
merge_kwargs!(rt; vcrop_mode=:middle, crop_num_lines_at_end=10)

# You can also access pretty_kwargs directly for advanced customization:
rt.pretty_kwargs[:body_hlines] = [3, 5, 7]
rt.pretty_kwargs[:highlighters] = (Highlighter(...),)
rt.pretty_kwargs[:formatters] = (ft_printf("%.4f", [2, 3]),)
```

# Note
For advanced users: You can directly manipulate `rt.pretty_kwargs` dictionary
to access the full PrettyTables.jl API without needing wrapper functions.
See the PrettyTables.jl documentation for all available options.
"""
function merge_kwargs!(rt::ModelSummary; kwargs...)
    merge!(rt.pretty_kwargs, Dict{Symbol, Any}(kwargs))
    rt
end

# Make ModelSummary act like a matrix for compatibility
Base.size(rt::ModelSummary) = size(rt.data)
Base.size(rt::ModelSummary, i::Int) = size(rt.data, i)
Base.getindex(rt::ModelSummary, i::Int, j::Int) = rt.data[i, j]
function Base.setindex!(rt::ModelSummary, val, i::Int, j::Int)
    rt.data[i, j] = val
    rt
end

# Helper functions to convert alignment symbols to PrettyTables format
function _pt_alignment(align::Vector{Symbol})
    return align
end

function _convert_alignment_char(c::Char)
    c == 'l' ? :l : (c == 'c' ? :c : :r)
end

function _convert_alignment_string(s::String)
    [_convert_alignment_char(c) for c in s]
end

# Main printing function using PrettyTables
"""
    _render_table(io::IO, rt::ModelSummary, backend::Symbol)

Internal function to render the table using PrettyTables.jl.
"""
function _render_table(io::IO, rt::ModelSummary, backend::Symbol)
    # Prepare the full data matrix (header + body)
    nheader = length(rt.header)

    # Build alignment vector (header uses header_align, body uses body_align)
    alignment = rt.body_align

    # Adjust hlines to account for PrettyTables' header handling
    # PrettyTables puts an automatic line after headers, so we need to adjust our hlines
    hlines_adjusted = copy(rt.hlines)

    # PrettyTables configuration based on backend
    kwargs = copy(rt.pretty_kwargs)

    if backend == :text
        # Text backend doesn't use table_format - customization via kwargs only
        kwargs[:backend] = :text
        kwargs[:alignment] = alignment
        kwargs[:header_alignment] = rt.header_align
        # Text backend supports body_hlines
        if !isempty(hlines_adjusted)
            kwargs[:body_hlines] = hlines_adjusted
        end

    elseif backend == :ascii
        # ASCII backend uses text backend with ASCII-only table format
        if !haskey(kwargs, :table_format)
            kwargs[:table_format] = get(rt.table_format, backend, default_table_format(backend))
        end
        kwargs[:backend] = :text
        kwargs[:alignment] = alignment
        kwargs[:header_alignment] = rt.header_align
        # Text backend supports body_hlines
        if !isempty(hlines_adjusted)
            kwargs[:body_hlines] = hlines_adjusted
        end

    elseif backend == :markdown
        # Set table format for markdown (PrettyTables 3.x uses table_format keyword, not tf)
        if !haskey(kwargs, :table_format)
            kwargs[:table_format] = get(rt.table_format, backend, default_table_format(backend))
        end
        kwargs[:backend] = :markdown
        kwargs[:alignment] = alignment
        kwargs[:column_label_alignment] = rt.header_align
        # Note: Markdown backend in PrettyTables 3.x doesn't support body_hlines

    elseif backend == :html
        # Set table format for HTML
        if !haskey(kwargs, :table_format)
            kwargs[:table_format] = get(rt.table_format, backend, default_table_format(backend))
        end
        kwargs[:backend] = :html
        kwargs[:alignment] = alignment
        kwargs[:column_label_alignment] = rt.header_align
        # HTML backend doesn't support body_hlines directly either

    elseif backend == :latex
        # Set table format for LaTeX
        if !haskey(kwargs, :table_format)
            kwargs[:table_format] = get(rt.table_format, backend, default_table_format(backend))
        end
        kwargs[:backend] = :latex
        kwargs[:alignment] = alignment
        kwargs[:column_label_alignment] = rt.header_align
        # LaTeX backend supports body_hlines
        if !isempty(hlines_adjusted)
            kwargs[:body_hlines] = hlines_adjusted
        end
    end

    # Add formatters if any
    if !isempty(rt.formatters)
        kwargs[:formatters] = tuple(rt.formatters...)
    end

    # Add highlighters if any
    if !isempty(rt.highlighters)
        kwargs[:highlighters] = tuple(rt.highlighters...)
    end
    
    ## Organize header rows
    column_header = build_column_labels(rt.header)
    column_header = [column_header, rt.data[1,:]]

    # Render using PrettyTables
    PrettyTables.pretty_table(
        io,
        rt.data[2:end, :];
        column_labels=column_header,
        merge_column_label_cells = :auto,
        kwargs...
    )
end

function build_column_labels(header::Vector{Vector{String}})
    row = header[1]

    # drop leading empty cell (row label), if present
    if !isempty(row) && row[1] == ""
        row = row[2:end]
    end

    labels = Any[] # can contain both String and MultiColumn
    push!(labels, "")  # first cell is empty for row labels
       
    i = 1
    while i <= length(row)
        label = row[i]

        # skip empty cells entirely
        if isempty(label)
            i += 1
            continue
        end

        # count how many times this label repeats consecutively
        j = i + 1
        while j <= length(row) && row[j] == label
            j += 1
        end

        span = j - i

        if span == 1
            # single column, use plain label
            push!(labels, label)
        else
            # consecutive group, use MultiColumn
            push!(labels, MultiColumn(span, label))
        end

        i = j
    end

    return labels
end



# MIME-based display methods
function Base.show(io::IO, ::MIME"text/plain", rt::ModelSummary)
    backend = rt.backend === nothing ? :markdown : rt.backend
    _render_table(io, rt, backend)
end

function Base.show(io::IO, ::MIME"text/html", rt::ModelSummary)
    backend = rt.backend === nothing ? :html : rt.backend
    _render_table(io, rt, backend)
end

function Base.show(io::IO, ::MIME"text/latex", rt::ModelSummary)
    backend = rt.backend === nothing ? :latex : rt.backend
    _render_table(io, rt, backend)
end

# Default show method (uses text/plain)
function Base.show(io::IO, rt::ModelSummary)
    show(io, MIME("text/plain"), rt)
end

# Write to file
function Base.write(filename::String, rt::ModelSummary)
    open(filename, "w") do io
        # Detect backend from file extension
        backend = rt.backend
        if backend === nothing
            ext = lowercase(splitext(filename)[2])
            if ext == ".tex"
                backend = :latex
            elseif ext in (".html", ".htm")
                backend = :html
            else
                backend = :text
            end
        end
        _render_table(io, rt, backend)
    end
end

#=============================================================================
Compatibility constructor for old DataRow-based system
=============================================================================#

"""
    ModelSummary(data::Vector{DataRow{T}}, align::String, breaks::Vector{Int}) where {T<:AbstractRenderType}

Constructor that converts DataRow-based tables to PrettyTables-based format.
This allows modelsummary() to build tables using the DataRow system internally.
"""
function ModelSummary(
    data::Vector{DataRow{T}},
    align::String,
    breaks::Vector{Int}=Int[],
    colwidths::Vector{Int}=Int[];
    table_format=nothing
) where {T<:AbstractRenderType}
    # Convert DataRow vector to matrix format
    nrows = length(data)
    if nrows == 0
        error("Cannot create table from empty DataRow vector")
    end

    # Determine table structure
    # First rows with underlines are headers, rest are body
    header_rows = Int[]
    for (i, row) in enumerate(data)
        if any(row.print_underlines)
            push!(header_rows, i)
        else
            break  # Once we hit a row without underlines, we're in the body
        end
    end

    nheader = length(header_rows)
    if nheader == 0
        # No header rows, treat first row as header
        nheader = 1
        header_rows = [1]
    end

    # Determine number of columns from first row
    # Handle multicolumn cells (Pairs)
    function count_cols(row::DataRow)
        n = 0
        for item in row.data
            if isa(item, Pair)
                n += length(last(item))
            else
                n += 1
            end
        end
        n
    end

    ncols = count_cols(data[1])

    # Convert rows to flat vectors (expanding multicolumn cells)
    function expand_row(row::DataRow, ncols::Int)
        result = fill("", ncols)
        col = 1
        for item in row.data
            if isa(item, Pair)
                # Multicolumn cell
                value = repr(row.render, first(item))
                span = length(last(item))
                # Put value in first column of span
                result[col] = value
                # Mark other columns as part of multicolumn (we'll handle in PrettyTables)
                for j in 1:(span-1)
                    result[col + j] = ""  # Empty for now, PrettyTables will handle merging
                end
                col += span
            else
                result[col] = repr(row.render, item)
                col += 1
            end
        end
        result
    end

    # Build header matrix
    header_matrix = Matrix{String}(undef, nheader, ncols)
    for (i, row_idx) in enumerate(header_rows)
        header_matrix[i, :] = expand_row(data[row_idx], ncols)
    end

    # Build body matrix
    body_start = nheader + 1
    nbody = nrows - nheader
    body_matrix = Matrix{Any}(undef, nbody, ncols)
    for i in 1:nbody
        body_matrix[i, :] = expand_row(data[body_start + i - 1], ncols)
    end

    # Convert alignment string to symbol vector
    align_vec = [c == 'l' ? :l : (c == 'c' ? :c : :r) for c in align]

    # Ensure we have alignment for all columns
    while length(align_vec) < ncols
        push!(align_vec, :r)
    end

    # Build header as vector of vectors (one per header row)
    header_vecs = [String[header_matrix[i, j] for j in 1:ncols] for i in 1:nheader]

    # Create alignment vectors
    header_align = fill(:c, ncols)
    header_align[1] = :l  # First column left-aligned

    body_align = copy(align_vec[1:ncols])

    # Adjust breaks (they're 1-indexed in old system, need to subtract header rows)
    adjusted_breaks = Int[b - nheader for b in breaks if b > nheader]

    # Determine backend from render type
    backend = if T <: AbstractLatex
        :latex
    elseif T <: AbstractHtml
        :html
    else
        nothing  # Auto-detect
    end

    # Create new ModelSummary
    rt = ModelSummary(
        body_matrix,
        header_vecs,
        header_align,
        body_align;
        hlines=adjusted_breaks,
        backend=backend,
        table_format=table_format
    )

    return rt
end
