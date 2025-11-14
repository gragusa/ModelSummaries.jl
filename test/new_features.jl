using ModelSummaries
using PrettyTables
using Test

@testset "Horizontal lines across backends" begin
    # Create a simple table
    body = Any[
        "(Intercept)" 1.0;
        "" "(0.1)";
        "x" 2.0;
        "" "(0.2)";
    ]

    ms = ModelSummary(["", "Model 1"], body)

    # Add horizontal lines
    add_hline!(ms, 2)

    @test 2 in ms.hlines
    @test length(ms.hlines) == 1

    # Test that hlines appear in output for text backend
    buf = IOBuffer()
    show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
    output = String(take!(buf))
    # The output should contain the table (exact format depends on PrettyTables)
    @test length(output) > 0

    # Test LaTeX backend
    buf = IOBuffer()
    show(IOContext(buf, :limit => false), MIME("text/latex"), ms)
    latex_output = String(take!(buf))
    @test length(latex_output) > 0

    # Test HTML backend
    buf = IOBuffer()
    show(IOContext(buf, :limit => false), MIME("text/html"), ms)
    html_output = String(take!(buf))
    @test length(html_output) > 0

    # Test remove_hline!
    remove_hline!(ms, 2)
    @test isempty(ms.hlines)
end

@testset "Horizontal lines - multiple lines" begin
    body = Any[
        "(Intercept)" 1.0;
        "" "(0.1)";
        "x" 2.0;
        "" "(0.2)";
        "z" 3.0;
        "" "(0.3)";
    ]

    ms = ModelSummary(["", "Model 1"], body)

    # Add multiple horizontal lines
    add_hline!(ms, 2)
    add_hline!(ms, 4)

    @test ms.hlines == [2, 4]

    # Adding the same line again should not duplicate
    add_hline!(ms, 2)
    @test ms.hlines == [2, 4]

    # Remove one line
    remove_hline!(ms, 2)
    @test ms.hlines == [4]
end

@testset "Theme system - preset themes" begin
    body = Any[
        "(Intercept)" 1.0;
        "" "(0.1)";
    ]

    # Test each preset theme
    for theme_name in [:academic, :modern, :minimal, :compact, :unicode, :default]
        theme = ModelSummaries.Themes.get_theme(theme_name)

        @test theme isa Dict
        @test haskey(theme, :text)
        @test haskey(theme, :html)
        @test haskey(theme, :latex)

        # Each value should be a TableFormat
        @test theme[:text] isa PrettyTables.TableFormat
        @test theme[:html] isa PrettyTables.TableFormat
        @test theme[:latex] isa PrettyTables.TableFormat

        # Create table with theme via table_format
        ms = ModelSummary(["", "Model 1"], body; table_format=theme)

        @test ms.table_format[:text] == theme[:text]
        @test ms.table_format[:html] == theme[:html]
        @test ms.table_format[:latex] == theme[:latex]
    end
end

@testset "Theme system - academic theme specifics" begin
    academic = ModelSummaries.Themes.ACADEMIC

    @test academic[:text] == PrettyTables.tf_markdown
    @test academic[:html] == PrettyTables.tf_html_minimalist
    @test academic[:latex] == PrettyTables.tf_latex_booktabs
end

@testset "Theme system - unknown theme" begin
    @test_throws ArgumentError ModelSummaries.Themes.get_theme(:nonexistent)
end

@testset "Theme system - custom theme" begin
    body = Any[
        "(Intercept)" 1.0;
        "" "(0.1)";
    ]

    # Custom theme as Dict
    custom_theme = Dict(
        :text => PrettyTables.tf_unicode_rounded,
        :html => PrettyTables.tf_html_simple,
        :latex => PrettyTables.tf_latex_simple
    )

    theme = ModelSummaries.Themes.get_theme(custom_theme)
    @test theme == custom_theme

    # Custom theme as NamedTuple
    custom_nt = (
        text = PrettyTables.tf_unicode,
        html = PrettyTables.tf_html_minimalist,
        latex = PrettyTables.tf_latex_booktabs
    )

    theme_from_nt = ModelSummaries.Themes.get_theme(custom_nt)
    @test theme_from_nt isa Dict
    @test theme_from_nt[:text] == custom_nt.text
end

@testset "Theme system - list_themes" begin
    # Test that list_themes doesn't error
    buf = IOBuffer()
    redirect_stdout(buf) do
        ModelSummaries.Themes.list_themes()
    end
    output = String(take!(buf))

    @test occursin("academic", output)
    @test occursin("modern", output)
    @test occursin("minimal", output)
end

@testset "Direct pretty_kwargs access" begin
    body = Any[
        "(Intercept)" 1.0;
        "" "(0.1)";
    ]

    ms = ModelSummary(["", "Model 1"], body)

    # Test direct access to pretty_kwargs
    ms.pretty_kwargs[:title] = "My Table"
    @test ms.pretty_kwargs[:title] == "My Table"

    # Test merge_kwargs!
    merge_kwargs!(ms; title_alignment=:c, crop_num_lines_at_end=10)
    @test ms.pretty_kwargs[:title_alignment] == :c
    @test ms.pretty_kwargs[:crop_num_lines_at_end] == 10

    # Original title should still be there
    @test ms.pretty_kwargs[:title] == "My Table"
end

@testset "Backend and theme interaction" begin
    body = Any[
        "(Intercept)" 1.0;
        "" "(0.1)";
    ]

    # Create table with specific backend
    ms = ModelSummary(["", "Model 1"], body; backend=:latex)

    @test ms.backend == :latex

    # Change backend
    set_backend!(ms, :html)
    @test ms.backend == :html

    # Reset to auto-detect
    set_backend!(ms, nothing)
    @test ms.backend === nothing
end

@testset "Alignment functions" begin
    body = Any[
        "(Intercept)" 1.0 2.0;
        "" "(0.1)" "(0.2)";
    ]

    ms = ModelSummary(["", "Model 1", "Model 2"], body)

    # Test set_alignment! for body
    set_alignment!(ms, 2, :c)
    @test ms.body_align[2] == :c

    # Test set_alignment! for header
    set_alignment!(ms, 3, :l; header=true)
    @test ms.header_align[3] == :l

    # Invalid alignment should error
    @test_throws AssertionError set_alignment!(ms, 1, :invalid)
end
