using ModelSummaries
using ModelSummaries.Themes
using PrettyTables
using Test

@testset "Horizontal lines across backends" begin
    # Create a simple table
    body = Any["(Intercept)" 1.0;
               "" "(0.1)";
               "x" 2.0;
               "" "(0.2)";]

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
    body = Any["(Intercept)" 1.0;
               "" "(0.1)";
               "x" 2.0;
               "" "(0.2)";
               "z" 3.0;
               "" "(0.3)";]

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
    for name in Themes.THEME_NAMES
        theme = Themes.get_theme(name)
        @test theme isa Dict{Symbol, Any}
        @test haskey(theme, :text)
    end
end

@testset "Theme system - academic theme specifics" begin
    theme = Themes.get_theme(:academic)
    @test haskey(theme, :text)
    @test haskey(theme, :latex)
    @test haskey(theme, :html)
    @test Themes.ACADEMIC === Themes.DEFAULT
end

@testset "Theme system - unknown theme" begin
    @test_throws ArgumentError Themes.get_theme(:nonexistent)
end

@testset "Theme system - custom theme" begin
    custom = Dict{Symbol, Any}(:text => PrettyTables.text_table_format__matrix)
    @test Themes.get_theme(custom) === custom

    custom_nt = (; text = PrettyTables.text_table_format__matrix)
    result = Themes.get_theme(custom_nt)
    @test result isa Dict{Symbol, Any}
    @test haskey(result, :text)
end

@testset "Theme system - list_themes" begin
    @test :academic in Themes.THEME_NAMES
    @test :modern in Themes.THEME_NAMES
    @test :stargazer in Themes.THEME_NAMES
    @test length(Themes.THEME_NAMES) == 7
    # list_themes() prints without error
    mktemp() do path, io
        redirect_stdout(io) do
            Themes.list_themes()
        end
        flush(io)
        output = read(path, String)
        @test occursin("academic", output)
    end
end

@testset "Direct pretty_kwargs access" begin
    body = Any["(Intercept)" 1.0;
               "" "(0.1)";]

    ms = ModelSummary(["", "Model 1"], body)

    # Test direct access to pretty_kwargs
    ms.pretty_kwargs[:title] = "My Table"
    @test ms.pretty_kwargs[:title] == "My Table"

    # Test merge_kwargs!
    merge_kwargs!(ms; title_alignment = :c, crop_num_lines_at_end = 10)
    @test ms.pretty_kwargs[:title_alignment] == :c
    @test ms.pretty_kwargs[:crop_num_lines_at_end] == 10

    # Original title should still be there
    @test ms.pretty_kwargs[:title] == "My Table"
end

@testset "Backend and theme interaction" begin
    body = Any["(Intercept)" 1.0;
               "" "(0.1)";]

    # Create table with specific backend
    ms = ModelSummary(["", "Model 1"], body; backend = :latex)

    @test ms.backend == :latex

    # Change backend
    set_backend!(ms, :html)
    @test ms.backend == :html

    # Typst backend is supported
    set_backend!(ms, :typst)
    @test ms.backend == :typst

    # Reset to auto-detect
    set_backend!(ms, nothing)
    @test ms.backend === nothing
end

@testset "Alignment functions" begin
    body = Any["(Intercept)" 1.0 2.0;
               "" "(0.1)" "(0.2)";]

    ms = ModelSummary(["", "Model 1", "Model 2"], body)

    # Test set_alignment! for body
    set_alignment!(ms, 2, :c)
    @test ms.body_align[2] == :c

    # Test set_alignment! for header
    set_alignment!(ms, 3, :l; header = true)
    @test ms.header_align[3] == :l

    # Invalid alignment should error
    @test_throws AssertionError set_alignment!(ms, 1, :invalid)
end
