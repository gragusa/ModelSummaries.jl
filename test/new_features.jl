using ModelSummaries
using Test
using SummaryTables: Table
using GLM, DataFrames

@testset "SummaryTables integration" begin
    df = DataFrame(y = randn(50), x = randn(50))
    m = lm(@formula(y ~ x), df)

    t = modelsummary(m)
    @test t isa Table

    # Verify all output backends work
    for mime in [MIME"text/html"(), MIME"text/latex"(), MIME"text/typst"()]
        buf = IOBuffer()
        show(buf, mime, t)
        @test length(take!(buf)) > 0
    end
end

@testset "Unicode labels" begin
    @test ModelSummaries.label(R2) == "R\u00b2"
    @test ModelSummaries.label(AdjR2) == "Adjusted R\u00b2"
    @test ModelSummaries.label(Nobs) == "N"
    @test ModelSummaries.label(AIC) == "AIC"
    @test ModelSummaries.label(BIC) == "BIC"
    @test ModelSummaries.label(FStat) == "F"
end

@testset "Display name functions" begin
    @test ModelSummaries.display_name(ModelSummaries.CoefName("x1")) == "x1"
    @test ModelSummaries.display_name(ModelSummaries.InterceptCoefName()) == "(Intercept)"
    @test ModelSummaries.display_name(
        ModelSummaries.CategoricalCoefName("species", "setosa")) == "species: setosa"
    @test ModelSummaries.display_name(
        ModelSummaries.InteractedCoefName([
        ModelSummaries.CoefName("x1"),
        ModelSummaries.CoefName("x2")])) == "x1 × x2"
end

@testset "Significance stars" begin
    @test ModelSummaries.significance_stars(0.0001) == "***"
    @test ModelSummaries.significance_stars(0.005) == "**"
    @test ModelSummaries.significance_stars(0.03) == "*"
    @test ModelSummaries.significance_stars(0.1) == ""
    @test ModelSummaries.significance_stars(NaN) == ""
end
