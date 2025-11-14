# Render type system for table construction
# This file contains only type definitions, no methods

"""
    abstract type AbstractRenderType end

Compatibility type for old rendering system.
Used internally during table construction, then converted to PrettyTables format.
"""
abstract type AbstractRenderType end

Base.broadcastable(o::AbstractRenderType) = Ref(o)

# Minimal render type implementations for compatibility
abstract type AbstractAscii <: AbstractRenderType end
abstract type AbstractLatex <: AbstractRenderType end
abstract type AbstractHtml <: AbstractRenderType end

struct AsciiTable <: AbstractAscii end
struct LatexTable <: AbstractLatex end
struct LatexTableStar <: AbstractLatex end
struct HtmlTable <: AbstractHtml end

# DataRow compatibility type
"""
    mutable struct DataRow{T<:AbstractRenderType}
        data::Vector
        align::String
        print_underlines::Vector{Bool}
    end

Compatibility type for old DataRow system.
Used internally during table construction.
"""
mutable struct DataRow{T<:AbstractRenderType}
    data::Vector
    align::String
    print_underlines::Vector{Bool}
    render::T

    function DataRow(
        data::Vector,
        align,
        print_underlines,
        render::T;
        kwargs...
    ) where {T<:AbstractRenderType}
        new{T}(data, align, print_underlines, render)
    end

    # Constructor that accepts colwidths as positional arg (but doesn't use it)
    # This is for backward compatibility with regtable.jl call sites
    function DataRow(
        data::Vector,
        align,
        colwidths,  # accepted but not stored
        print_underlines,
        render::T;
        kwargs...
    ) where {T<:AbstractRenderType}
        new{T}(data, align, print_underlines, render)
    end
end
