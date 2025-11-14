"""
Theme presets for ModelSummaries.jl

This module provides pre-configured theme presets that combine table formats
for different backends (text, HTML, LaTeX) with beautiful, consistent styling.

# Available Themes

- `:academic` - Clean, professional style suitable for academic publications
- `:modern` - Sleek modern style with unicode box-drawing characters
- `:minimal` - Minimalist style with simple lines
- `:compact` - Space-efficient style for dense tables
- `:default` - Default ModelSummaries.jl theme (booktabs-style)

# Usage

```julia
using ModelSummaries

# Use a preset theme
modelsummary(model1, model2; theme=:academic)
modelsummary(model1, model2; theme=:modern)

# Or use the Themes module directly
using ModelSummaries.Themes
modelsummary(model1, model2; theme=Themes.ACADEMIC)
```

# Custom Themes

You can create custom themes by providing a Dict or NamedTuple:

```julia
my_theme = Dict(
    :text => PrettyTables.tf_unicode_rounded,
    :html => PrettyTables.tf_html_minimalist,
    :latex => PrettyTables.tf_latex_booktabs
)
modelsummary(model1, model2; theme=my_theme)
```
"""
module Themes

using PrettyTables

"""
    ACADEMIC

Professional academic publication style using booktabs aesthetics across all backends.
Best for: Journal articles, dissertations, academic papers.

- Text: Clean markdown with minimal decorations
- HTML: Default HTML styling
- LaTeX: Classic booktabs style with \\toprule, \\midrule, \\bottomrule
"""
const ACADEMIC = Dict{Symbol, Any}(
    :text => PrettyTables.MarkdownTableFormat(),
    :html => PrettyTables.HtmlTableFormat(),
    :latex => PrettyTables.latex_table_format__booktabs
)

"""
    MODERN

Modern, visually appealing style with unicode box-drawing characters.
Best for: Presentations, modern reports, terminal display.

- Text: Unicode boxes for elegant terminal output
- HTML: Default HTML styling
- LaTeX: Booktabs LaTeX style
"""
const MODERN = Dict{Symbol, Any}(
    :text => PrettyTables.MarkdownTableFormat(),
    :html => PrettyTables.HtmlTableFormat(),
    :latex => PrettyTables.latex_table_format__booktabs
)

"""
    MINIMAL

Minimalist style with clean lines and minimal visual elements.
Best for: Simple tables, quick reports, embedded documentation.

- Text: Matrix-style text format
- HTML: Default HTML
- LaTeX: Booktabs LaTeX
"""
const MINIMAL = Dict{Symbol, Any}(
    :text => PrettyTables.MarkdownTableFormat(),
    :html => PrettyTables.HtmlTableFormat(),
    :latex => PrettyTables.latex_table_format__booktabs
)

"""
    COMPACT

Space-efficient style for dense tables with lots of data.
Best for: Large tables, space-constrained outputs.

- Text: Matrix-style (compact) layout
- HTML: Default HTML with minimal padding
- LaTeX: Booktabs style
"""
const COMPACT = Dict{Symbol, Any}(
    :text => PrettyTables.MarkdownTableFormat(),
    :html => PrettyTables.HtmlTableFormat(),
    :latex => PrettyTables.latex_table_format__booktabs
)

"""
    DEFAULT

Default ModelSummaries.jl theme (same as :academic).
Provides sensible defaults for all backends.

- Text: Markdown format
- HTML: Default HTML
- LaTeX: Booktabs style
"""
const DEFAULT = ACADEMIC

"""
    UNICODE

Clean unicode-based tables for terminal display.
Best for: Terminal output, REPLs, modern consoles.

- Text: Standard unicode box-drawing
- HTML: Default HTML
- LaTeX: Booktabs
"""
const UNICODE = Dict{Symbol, Any}(
    :text => PrettyTables.MarkdownTableFormat(),
    :html => PrettyTables.HtmlTableFormat(),
    :latex => PrettyTables.latex_table_format__booktabs
)

# List of all available theme names
const THEME_NAMES = [
    :academic, :modern, :minimal, :compact, :default, :unicode
]

"""
    get_theme(name::Symbol)

Get a theme by name. Returns the corresponding theme Dict.

# Arguments
- `name::Symbol`: One of `:academic`, `:modern`, `:minimal`, `:compact`, `:default`, or `:unicode`

# Returns
- `Dict{Symbol, Any}`: Theme configuration mapping backend symbols to TableFormat objects

# Throws
- `ArgumentError`: If theme name is not recognized

# Examples
```julia
theme = get_theme(:academic)
theme = get_theme(:modern)
```
"""
function get_theme(name::Symbol)
    if name == :academic
        return ACADEMIC
    elseif name == :modern
        return MODERN
    elseif name == :minimal
        return MINIMAL
    elseif name == :compact
        return COMPACT
    elseif name == :default
        return DEFAULT
    elseif name == :unicode
        return UNICODE
    else
        available = join(THEME_NAMES, ", ", " or ")
        throw(ArgumentError("Unknown theme :$name. Available themes: $available"))
    end
end

"""
    get_theme(theme_dict::AbstractDict)

Pass-through for custom theme dictionaries.

# Arguments
- `theme_dict::AbstractDict`: Custom theme configuration

# Returns
- The same dictionary (for consistency with Symbol-based get_theme)
"""
get_theme(theme_dict::AbstractDict) = theme_dict

"""
    get_theme(theme_nt::NamedTuple)

Convert NamedTuple theme to Dict.

# Arguments
- `theme_nt::NamedTuple`: Custom theme configuration as NamedTuple

# Returns
- `Dict{Symbol, Any}`: Theme configuration as dictionary
"""
get_theme(theme_nt::NamedTuple) = Dict{Symbol, Any}(pairs(theme_nt))

"""
    list_themes()

Print a list of all available theme names with descriptions.

# Examples
```julia
julia> Themes.list_themes()
Available ModelSummaries.jl themes:
  - academic:  Professional academic publication style
  - modern:    Modern style with unicode box-drawing
  - minimal:   Minimalist style with clean lines
  - compact:   Space-efficient style for dense tables
  - default:   Default ModelSummaries.jl theme
  - unicode:   Clean unicode-based terminal tables
```
"""
function list_themes()
    println("Available ModelSummaries.jl themes:")
    println("  - academic:  Professional academic publication style")
    println("  - modern:    Modern style with unicode box-drawing")
    println("  - minimal:   Minimalist style with clean lines")
    println("  - compact:   Space-efficient style for dense tables")
    println("  - default:   Default ModelSummaries.jl theme")
    println("  - unicode:   Clean unicode-based terminal tables")
end

end # module Themes
