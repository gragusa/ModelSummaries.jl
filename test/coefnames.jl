using ModelSummaries
using Test
using GLM, DataFrames

const MS = ModelSummaries

@testset "Wrapped coefficient names compare by content" begin
    inter() = MS.InteractedCoefName([MS.CoefName("a"), MS.CoefName("b")])
    swapped = MS.InteractedCoefName([MS.CoefName("b"), MS.CoefName("a")])
    for W in (MS.FixedEffectCoefName, MS.ClusterCoefName, MS.FirstStageCoefName)
        @test W(inter()) == W(inter())
        @test W(inter()) == W(swapped)
        @test hash(W(inter())) == hash(W(swapped))
        @test W(MS.CoefName("a")) != W(MS.CoefName("b"))
        @test length(unique([W(inter()), W(inter()), W(MS.CoefName("a"))])) == 2
    end
    @test MS.FixedEffectCoefName(MS.CoefName("a")) != MS.ClusterCoefName(MS.CoefName("a"))
end

@testset "Interaction separator" begin
    x = MS.InteractedCoefName([MS.CoefName("x1"), MS.CoefName("x2")])
    @test string(x) == "x1 & x2"
    @test MS.display_name(x) == "x1 × x2"
    @test MS.display_name(x, " : ") == "x1 : x2"
    @test MS.display_name(MS.FixedEffectCoefName(x), " : ") == "x1 : x2"

    df = DataFrame(y = [1.0, 3, 2, 5, 4, 7, 6, 9], x1 = [1.0, 2, 3, 4, 5, 6, 7, 8],
        x2 = [2.0, 1, 4, 3, 6, 5, 8, 9])
    m = lm(@formula(y ~ x1 * x2), df)
    html(t) = sprint(show, MIME"text/html"(), t)

    @test occursin("x1 × x2", html(modelsummary(m)))
    out = html(modelsummary(m; interaction_separator = " * "))
    @test occursin("x1 * x2", out)
    @test !occursin("x1 × x2", out)

    # `labels` keys use StatsModels' " & " form; a label replaces the whole name.
    out = html(modelsummary(m; labels = Dict("x1 & x2" => "Both")))
    @test occursin("Both", out)
    @test !occursin("x1 × x2", out)
    @test_throws "matches no name" modelsummary(m; keep = ["x1 × x2"])
    @test occursin("x1 × x2", html(modelsummary(m; keep = ["x1 & x2"])))
end
