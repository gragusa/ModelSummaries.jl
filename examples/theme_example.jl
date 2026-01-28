# Theme Example for ModelSummaries.jl
#
# This example demonstrates how to use the theme system to create beautiful
# regression tables with different visual styles.

using DataFrames
using GLM
using ModelSummaries

# Create sample data
println("Creating sample data...")
df = DataFrame(
    y = randn(100),
    x1 = randn(100),
    x2 = randn(100),
    x3 = randn(100),
    z = repeat(1:2, inner = 50)
)

# Fit multiple models
println("Fitting models...")
m1 = lm(@formula(y ~ x1), df)
m2 = lm(@formula(y ~ x1 + x2), df)
m3 = lm(@formula(y ~ x1 + x2 + x3), df)

println("\n" * "="^80)
println("THEME EXAMPLES")
println("="^80)

# Example 1: Academic theme (default)
println("\n1. ACADEMIC THEME (Publication style)")
println("-" * "="^79)
ms_academic = modelsummary(m1, m2, m3;
    theme = :academic,
    regression_statistics = [Nobs, R2, AdjR2],
    labels = Dict(
        "x1" => "Treatment",
        "x2" => "Control 1",
        "x3" => "Control 2"
    )
)
display(ms_academic)

# Example 2: Modern theme
println("\n2. MODERN THEME (Clean markdown)")
println("-" * "="^79)
ms_modern = modelsummary(m1, m2, m3;
    theme = :modern,
    regression_statistics = [Nobs, R2],
    labels = Dict(
        "x1" => "Treatment",
        "x2" => "Control 1",
        "x3" => "Control 2"
    )
)
display(ms_modern)

# Example 3: Minimal theme
println("\n3. MINIMAL THEME (Simple and clean)")
println("-" * "="^79)
ms_minimal = modelsummary(m1, m2;
    theme = :minimal,
    regression_statistics = [Nobs, R2]
)
display(ms_minimal)

# Example 4: Compact theme
println("\n4. COMPACT THEME (Space-efficient)")
println("-" * "="^79)
ms_compact = modelsummary(m1, m2, m3;
    theme = :compact,
    regression_statistics = [Nobs, R2],
    labels = Dict("x1" => "X1", "x2" => "X2", "x3" => "X3")
)
display(ms_compact)

# Example 5: Unicode theme
println("\n5. UNICODE THEME (Terminal-friendly)")
println("-" * "="^79)
ms_unicode = modelsummary(m1, m2;
    theme = :unicode,
    regression_statistics = [Nobs, R2]
)
display(ms_unicode)

# Example 6: Custom theme
println("\n6. CUSTOM THEME (User-defined)")
println("-" * "="^79)
using PrettyTables

custom_theme = Dict(
    :text => PrettyTables.MarkdownTableFormat(),
    :html => PrettyTables.HtmlTableFormat(),
    :latex => PrettyTables.latex_table_format__booktabs
)

ms_custom = modelsummary(m1, m2;
    theme = custom_theme,
    regression_statistics = [Nobs, R2, AdjR2, FStat]
)
display(ms_custom)

# Example 7: Theme with post-creation customization
println("\n7. THEME WITH CUSTOMIZATION")
println("-" * "="^79)
ms = modelsummary(m1, m2, m3;
    theme = :academic,
    regression_statistics = [Nobs, R2, AdjR2]
)

# Add horizontal line after coefficients
add_hline!(ms, 3)

# Add custom title via PrettyTables kwargs
merge_kwargs!(ms; title = "Regression Results", title_alignment = :c)

display(ms)

# Example 8: Listing available themes
println("\n8. AVAILABLE THEMES")
println("-" * "="^79)
println("\nUse Themes.list_themes() to see all available themes:")
ModelSummaries.Themes.list_themes()

# Example 9: Saving to file with theme
println("\n9. SAVING TO FILE")
println("-" * "="^79)
println("Saving tables to files...")

# Save as LaTeX (booktabs style)
modelsummary(m1, m2, m3;
    theme = :academic,
    backend = :latex,
    file = "/tmp/results_academic.tex",
    regression_statistics = [Nobs, R2, AdjR2]
)
println("✓ Saved LaTeX table to /tmp/results_academic.tex")

# Save as HTML
modelsummary(m1, m2, m3;
    theme = :modern,
    backend = :html,
    file = "/tmp/results_modern.html",
    regression_statistics = [Nobs, R2, AdjR2]
)
println("✓ Saved HTML table to /tmp/results_modern.html")

# Save as Markdown
modelsummary(m1, m2, m3;
    theme = :minimal,
    backend = :text,
    file = "/tmp/results_minimal.md",
    regression_statistics = [Nobs, R2]
)
println("✓ Saved Markdown table to /tmp/results_minimal.md")

println("\n" * "="^80)
println("THEME COMPARISON GUIDE")
println("="^80)
println("""
Theme Recommendations:
- :academic  → Journal articles, dissertations, formal publications
- :modern    → Reports, presentations, modern documents
- :minimal   → Simple tables, quick reports, embedded docs
- :compact   → Large tables with many columns/rows
- :unicode   → Terminal output, REPLs, console display
- :default   → Same as :academic (safe default choice)

Key Features:
• All themes work across text, HTML, and LaTeX backends
• Themes are applied once at table creation
• Can be customized post-creation with add_hline!, merge_kwargs!, etc.
• Custom themes supported via Dict or NamedTuple
• See PRETTYTABLES_GUIDE.md for advanced customization
""")

println("\n✓ Example completed successfully!")
