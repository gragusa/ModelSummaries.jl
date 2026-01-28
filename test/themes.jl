using ModelSummaries
using DataFrames
using GLM
using Test
using ModelSummaries.Themes

@testset "Themes" begin
    df = DataFrame(y = randn(20), x1 = randn(20))
    m = lm(@formula(y ~ x1), df)

    # Test that all themes run without error
    for theme_name in Themes.THEME_NAMES
        @testset "Theme: $theme_name" begin
            # Text backend
            ms = modelsummary(m; theme = theme_name)
            @test ms.table_format[:text] !== nothing

            # Capture output
            io = IOBuffer()
            show(io, "text/plain", ms)
            out = String(take!(io))
            @test length(out) > 0

            # Check specific characteristics for some themes
            if theme_name == :stargazer
                # Stargazer should not have vertical lines '|' usually, but depends on impl.
                # Our impl uses ' ' for vertical.
                @test !occursin("|", out)
                @test occursin("-", out)
            elseif theme_name == :modern
                # Modern uses rounded corners
                @test occursin("╭", out) || occursin("╮", out)
            end
        end
    end

    # Test invalid theme
    @test_throws ArgumentError modelsummary(m; theme = :non_existent_theme)
end
