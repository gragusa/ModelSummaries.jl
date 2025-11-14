# ModelSummaries.jl Improvement Recommendations

## Executive Summary

This document outlines recommendations to better align ModelSummaries.jl with the objective of maximizing PrettyTables.jl integration while maintaining excellent default themes and user customization capabilities.

**Core Objective**: Have statistics creation be separate from rendering, with PrettyTables.jl handling all table manipulation and display, while providing beautiful default themes that users can easily customize.

---

## Current State Analysis

### Strengths
1. ✅ Clean separation between statistics computation and rendering
2. ✅ PrettyTables.jl integration through `_render_table()`
3. ✅ `table_format` keyword supports custom themes per backend
4. ✅ Post-creation customization via helper functions
5. ✅ MIME-aware automatic backend detection

### Pain Points
1. ❌ **Compatibility Layer Overhead**: The DataRow-based system still drives table construction, requiring conversion to PrettyTables format
2. ❌ **Limited PrettyTables Feature Exposure**: Many PrettyTables.jl 3.0 features are not easily accessible
3. ❌ **Theme System Not Obvious**: Users may not discover the `table_format` capability
4. ❌ **Horizontal Lines Not Fully Working**: `hlines` field exists but isn't properly connected to PrettyTables backends
5. ❌ **Indirect Manipulation**: Users must use wrapper functions instead of directly working with PrettyTables constructs
6. ❌ **Header Building Complexity**: The `build_column_labels()` logic manually handles multicolumn, which PrettyTables can do natively

---

## Recommended Improvements

### 1. **Eliminate DataRow Intermediate Representation** (Priority: HIGH)

**Current Problem**: Statistics are computed → wrapped in DataRow objects → converted to ModelSummary matrix → rendered by PrettyTables. This creates unnecessary complexity and limits flexibility.

**Proposed Solution**:
- Refactor `modelsummary()` to build the data matrix directly without DataRow
- Move all formatting logic (repr, decorations) to happen during matrix construction
- Keep DataRow only as internal compatibility layer if needed for legacy code

**Benefits**:
- Cleaner code path: Statistics → Matrix → PrettyTables
- Easier to understand and maintain
- Better performance (one less conversion step)
- More natural for users who want to manipulate tables

**Implementation**:
```julia
# Instead of:
#   1. Create Vector{DataRow}
#   2. Convert DataRow → ModelSummary
#   3. Render ModelSummary

# Do:
#   1. Create Matrix{Any} directly from statistics
#   2. Store in ModelSummary
#   3. Render with PrettyTables

function modelsummary(models...; kwargs...)
    # Extract statistics
    stats = compute_statistics(models...)

    # Build matrix directly
    data = build_data_matrix(stats, kwargs...)
    header = build_header_matrix(stats, kwargs...)

    # Create ModelSummary (no conversion needed)
    ModelSummary(data, header, ...)
end
```

---

### 2. **Expose PrettyTables Constructs More Directly** (Priority: HIGH)

**Current Problem**: Users must use wrapper functions (`add_hline!`, `merge_kwargs!`, etc.) to customize tables. They can't easily use PrettyTables features directly.

**Proposed Solution**:
Create a more transparent API that exposes PrettyTables constructs:

```julia
# Option A: Direct property access
rt = modelsummary(m1, m2)
rt.pretty_table_options[:title] = "Results"
rt.pretty_table_options[:body_hlines] = [3, 5]
rt.pretty_table_options[:formatters] = (ft_printf("%.4f", [2, 3]),)

# Option B: to_prettytable() converter
pt_data, pt_options = to_prettytable(rt)
# Now users can manipulate pt_options directly using PrettyTables docs
pretty_table(pt_data; pt_options...)

# Option C: Hybrid (recommended)
# Keep convenience methods for common operations
add_hline!(rt, 3)  # Still works

# But also expose direct access for advanced users
rt.pretty_kwargs[:body_hlines] = [3, 5, 7]
rt.pretty_kwargs[:cell_alignment] = Dict((2,3) => :c)
```

**Benefits**:
- Users can leverage full PrettyTables.jl documentation
- No need to create wrapper functions for every PrettyTables feature
- More discoverable for users familiar with PrettyTables
- Easier to support new PrettyTables features

---

### 3. **Fix Horizontal Lines Implementation** (Priority: HIGH)

**Current Problem**: `hlines` field exists but doesn't properly integrate with PrettyTables backends. Code at `modelsummary_type.jl:360-362` is commented out.

**Proposed Solution**:
```julia
function _render_table(io::IO, rt::ModelSummary, backend::Symbol)
    kwargs = copy(rt.pretty_kwargs)

    # ... existing code ...

    # Fix horizontal lines for all backends
    if !isempty(rt.hlines)
        if backend == :latex
            kwargs[:body_hlines] = rt.hlines
        elseif backend == :text || backend == :markdown
            kwargs[:body_hlines] = rt.hlines
        elseif backend == :html
            # HTML backend doesn't have body_hlines, but we can use CSS classes
            # or add manual <tr> class attributes
            kwargs[:row_labels] = get_row_labels_with_hlines(rt.hlines)
        end
    end

    # ...
end
```

**Benefits**:
- `add_hline!()` actually works
- Tables look more professional with proper section separation
- Consistent behavior across backends

---

### 4. **Create Theme Presets** (Priority: MEDIUM)

**Current Problem**: Default themes are reasonable but not exceptional. Users don't know they can customize. No "batteries included" beautiful themes.

**Proposed Solution**:
Create a theme system with beautiful presets:

```julia
# Define theme presets
module Themes
    using PrettyTables

    # Academic publication style
    const ACADEMIC = Dict(
        :text => tf_unicode_rounded,
        :html => tf_html_simple,
        :latex => tf_latex_booktabs
    )

    # Modern/sleek style
    const MODERN = Dict(
        :text => tf_unicode,
        :html => tf_html_dark,
        :latex => tf_latex_modern
    )

    # Minimal style
    const MINIMAL = Dict(
        :text => tf_simple,
        :html => tf_html_minimalist,
        :latex => tf_latex_simple
    )

    # Colorful/presentation style (with Crayons)
    const PRESENTATION = Dict(
        :text => tf_unicode_rounded,
        # ... with custom colors, bold headers, etc.
    )
end

# Usage
modelsummary(m1, m2; theme = :academic)  # or Themes.ACADEMIC
modelsummary(m1, m2; theme = :modern)
modelsummary(m1, m2; theme = :minimal)

# Also support custom themes
my_theme = Dict(
    :text => my_custom_format,
    :latex => tf_latex_booktabs
)
modelsummary(m1, m2; theme = my_theme)
```

**Additional Enhancement**: Create custom PrettyTables `TableFormat` objects specifically for regression tables:

```julia
# Regression-specific table format with nice spacing, bold p-values, etc.
const tf_regression_modern = PrettyTables.TableFormat(
    # ... customized for regression tables
    # - Extra space between coefficient/SE rows
    # - Subtle background for statistic rows
    # - etc.
)
```

**Benefits**:
- Beautiful defaults out of the box
- Easy to switch between styles
- Users discover customization capability
- Can showcase in documentation/examples

---

### 5. **Improve Header/Multicolumn Handling** (Priority: MEDIUM)

**Current Problem**: `build_column_labels()` manually creates MultiColumn objects. PrettyTables can handle merging automatically with repeated header values.

**Proposed Solution**:
Simplify header construction to leverage PrettyTables' `merge_column_label_cells = :auto`:

```julia
# Instead of manually building MultiColumn objects
# Just pass the header matrix with repeated values and let PrettyTables merge

function build_column_labels(header::Vector{Vector{String}})
    # Simplified: just return the header rows as-is
    # PrettyTables will handle merging with merge_column_label_cells = :auto
    return reduce(vcat, [reshape(row, 1, :) for row in header])
end

# Or even simpler: don't build at all
function _render_table(io::IO, rt::ModelSummary, backend::Symbol)
    # ...

    # Pass header directly as multi-row matrix
    pretty_table(
        io,
        rt.data[2:end, :];
        column_labels = rt.header,  # Vector{Vector{String}} → automatic multi-row header
        merge_column_label_cells = :auto,
        kwargs...
    )
end
```

**Benefits**:
- Less custom code to maintain
- Leverage PrettyTables' built-in capabilities
- More flexible for complex headers

---

### 6. **Better Documentation of PrettyTables Integration** (Priority: MEDIUM)

**Current Problem**: Documentation shows the architecture but doesn't emphasize how to use PrettyTables features directly.

**Proposed Solution**:
Add a dedicated section to docs:

```markdown
## Working with PrettyTables.jl

ModelSummaries.jl uses PrettyTables.jl 3.0 for all rendering. This means you can
use ANY PrettyTables feature to customize your tables.

### Quick Examples

#### Using PrettyTables Formatters
\`\`\`julia
using PrettyTables

rt = modelsummary(m1, m2)

# Use any PrettyTables formatter
merge_kwargs!(rt;
    formatters = ft_printf("%.4f", [2, 3])  # Format columns 2-3
)
\`\`\`

#### Using PrettyTables Highlighters
\`\`\`julia
# Highlight significant results
h = Highlighter(
    f = (data, i, j) -> j > 1 && contains(string(data[i,j]), "***"),
    crayon = crayon"bold green"
)
merge_kwargs!(rt; highlighters = h)
\`\`\`

#### Custom Table Formats
\`\`\`julia
# Use any PrettyTables table format
modelsummary(m1, m2;
    table_format = Dict(
        :text => PrettyTables.tf_unicode_rounded,
        :latex => PrettyTables.tf_latex_booktabs
    )
)
\`\`\`

### See Also
- [PrettyTables.jl Documentation](https://ronisbr.github.io/PrettyTables.jl/stable/)
- [PrettyTables Formatters](...)
- [PrettyTables Highlighters](...)
```

**Benefits**:
- Users discover the full power of PrettyTables
- Less need to implement wrapper functions
- Better integration with Julia ecosystem

---

### 7. **Direct Matrix Access for Advanced Users** (Priority: LOW)

**Current Problem**: Once statistics are computed and table is built, users can't easily manipulate the underlying data except through indexed access.

**Proposed Solution**:
Add convenience methods for advanced manipulation:

```julia
# Get underlying PrettyTables-compatible data
data, header, options = components(rt)

# Modify directly
data[3, 2] = "0.45***"
header[1][2] = "Model 1 (Treatment)"

# Rebuild table
rt2 = ModelSummary(data, header; options...)

# Or update in place
update!(rt, data, header)
```

**Benefits**:
- Power users can do anything they need
- No artificial limitations
- Familiar to users of DataFrames, Tables.jl, etc.

---

### 8. **Leverage PrettyTables 3.0 Features** (Priority: LOW-MEDIUM)

**Current Problem**: Many PrettyTables 3.0 features aren't utilized:
- Cell-specific formatting
- Footers
- Custom cell rendering
- Conditional formatting
- Better merged cell support

**Proposed Solution**:
Add convenience functions that expose these features:

```julia
# Add footer row
add_footer!(rt, ["Notes:", "* p<0.1, ** p<0.05, *** p<0.01"])

# Cell-specific formatting
set_cell_format!(rt, row=3, col=2, format="%.6f")

# Conditional highlighting
highlight_if!(rt, condition = x -> x > 2.0, style = :bold)

# Custom cell renderer
set_cell_renderer!(rt, row=1, col=2, renderer = x -> "⭐ $x")
```

**Benefits**:
- More professional-looking tables
- Better for complex analyses
- Matches capabilities of R's modelsummary, Stata's esttab, etc.

---

## Implementation Roadmap

### Phase 1: Foundation (High Priority)
1. ✅ **Fix horizontal lines** - Quick win, high impact
2. ✅ **Eliminate DataRow conversion** - Major refactor but critical
3. ✅ **Expose PrettyTables constructs** - Better API design

### Phase 2: Polish (Medium Priority)
4. ✅ **Create theme presets** - User-facing improvement
5. ✅ **Improve header handling** - Simplification
6. ✅ **Better documentation** - Essential for adoption

### Phase 3: Advanced (Low Priority)
7. ✅ **Direct matrix access** - Power user feature
8. ✅ **Leverage PrettyTables 3.0** - Nice-to-have enhancements

---

## Specific Code Changes Needed

### File: `src/modelsummary.jl`
**Change**: Refactor main function to build matrix directly
```julia
# Remove DataRow construction loop
# Replace with direct matrix building
function modelsummary(rrs...; kwargs...)
    # ... existing parameter processing ...

    # NEW: Build matrix directly
    data_matrix = Matrix{Any}(undef, n_rows, n_cols)
    header_matrix = build_header_matrix(...)

    # Fill data_matrix with formatted values
    for (i, model) in enumerate(models)
        for (j, coef) in enumerate(coefs)
            # Format value directly, no DataRow wrapper
            data_matrix[j, i+1] = format_coef_value(coef, model, render_type)
        end
    end

    # Create ModelSummary directly
    ModelSummary(data_matrix, header_matrix, ...)
end
```

### File: `src/modelsummary_type.jl`
**Change 1**: Fix horizontal lines
```julia
function _render_table(io::IO, rt::ModelSummary, backend::Symbol)
    # ... existing code ...

    # ADD: Support body_hlines for all backends
    if !isempty(rt.hlines) && backend in (:latex, :text, :markdown)
        kwargs[:body_hlines] = rt.hlines
    end

    # UNCOMMENT lines 360-362 and implement properly
end
```

**Change 2**: Add theme system
```julia
# ADD: Theme module
module Themes
    const ACADEMIC = Dict(:text => ..., :html => ..., :latex => ...)
    const MODERN = Dict(...)
    const MINIMAL = Dict(...)
end

# MODIFY: Constructor to accept :theme keyword
function ModelSummary(...; theme=nothing, table_format=nothing, kwargs...)
    if theme !== nothing
        table_format = get_theme(theme)
    end
    # ... rest of constructor ...
end
```

### File: `src/compat/render_compat.jl`
**Change**: Make DataRow internal-only
```julia
# ADD: Deprecation notices
@deprecate DataRow "DataRow is deprecated and will be removed. Build matrices directly."

# KEEP: For backwards compatibility but don't expose in public API
# MOVE: All DataRow logic to internal/ subfolder
```

### File: `docs/src/prettytables_integration.md` (NEW)
**Add**: Complete guide to using PrettyTables features with ModelSummaries

---

## Breaking Changes to Consider

### Option A: Conservative (Recommended for v2.x)
- Keep all existing APIs working
- Add new features alongside
- Deprecate DataRow but keep functional
- Internal refactoring only

### Option B: Bold (For v3.0)
- Remove DataRow from public API completely
- Simplify API to be PrettyTables-first
- Remove wrapper functions in favor of direct manipulation
- Breaking but cleaner

**Recommendation**: Go with Option A for now, prepare for Option B in v3.0

---

## Testing Strategy

1. **Compatibility tests**: Ensure old code still works
2. **Theme tests**: Verify all themes render correctly
3. **PrettyTables integration tests**: Test formatters, highlighters, etc.
4. **Horizontal lines tests**: Verify hlines work across all backends
5. **Performance tests**: Ensure refactoring doesn't slow things down
6. **Visual tests**: Compare rendered output before/after changes

---

## Expected Benefits

### For Users
1. **Easier to use**: Work with familiar PrettyTables constructs
2. **More powerful**: Access to all PrettyTables features
3. **Better defaults**: Beautiful themes out of the box
4. **Better docs**: Can reference PrettyTables docs directly
5. **More flexible**: Can customize anything

### For Maintainers
1. **Less code**: Remove DataRow conversion layer
2. **Easier to maintain**: Leverage PrettyTables instead of reimplementing
3. **Better architecture**: Cleaner separation of concerns
4. **Easier to extend**: Just use PrettyTables features
5. **Better tested**: Rely on PrettyTables' test suite

### For Ecosystem
1. **Better integration**: Works naturally with PrettyTables ecosystem
2. **More discoverable**: Users finding PrettyTables also find ModelSummaries
3. **Standard interface**: Follows PrettyTables conventions
4. **Future-proof**: Automatically get new PrettyTables features

---

## Open Questions

1. **Theme naming**: What names for themes? (academic, modern, minimal, publication, presentation?)
2. **Default theme**: Keep current defaults or switch to a preset?
3. **API naming**: `theme` vs `table_format` vs `style`?
4. **Backwards compatibility**: How long to support DataRow?
5. **Documentation**: Separate guide or integrate into main docs?

---

## References

- [PrettyTables.jl 3.0 Documentation](https://ronisbr.github.io/PrettyTables.jl/stable/)
- [PrettyTables.jl 3.0 Announcement](https://discourse.julialang.org/t/ann-prettytables-v3-0-0/131821)
- [modelsummary (R package)](https://vincentarelbundock.github.io/modelsummary/) - Inspiration for themes
- [Great Tables (Python)](https://posit-dev.github.io/great-tables/) - Modern table theming inspiration

---

## Conclusion

The path forward is clear: **embrace PrettyTables.jl fully** rather than wrapping it. The current architecture is 80% there, but the DataRow compatibility layer and limited exposure of PrettyTables features hold it back.

By making the changes outlined above, ModelSummaries.jl will:
1. Be easier to use and more powerful
2. Have beautiful defaults that rival R/Stata packages
3. Require less maintenance (leverage PrettyTables instead of reimplementing)
4. Integrate better with the Julia ecosystem

The recommended approach is **incremental improvement** (Phase 1 → Phase 2 → Phase 3) with backwards compatibility maintained until a future major version.
