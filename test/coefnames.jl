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

@testset "Labels relabel the parts of a name" begin
    df = DataFrame(
        y = [1.0, 3, 2, 5, 4, 7, 6, 9, 8, 10], x1 = [1.0, 2, 3, 4, 5, 6, 7, 8, 9, 3],
        x2 = [2.0, 1, 4, 3, 6, 5, 8, 9, 7, 2],
        g = ["a", "b", "c", "a", "b", "c", "a", "b", "c", "a"])
    html(t) = sprint(show, MIME"text/html"(), t)

    x = MS.InteractedCoefName([MS.CoefName("x1"), MS.CoefName("x2")])
    @test MS.replace_name(x, Dict("x1" => "T"), Dict()) ==
          MS.InteractedCoefName(["T", MS.CoefName("x2")])
    @test MS.display_name(MS.replace_name(x, Dict("x1" => "T"), Dict())) == "T × x2"
    # The full-name key wins over the keys for its parts.
    @test MS.replace_name(x, Dict("x1" => "T", "x1 & x2" => "Both"), Dict()) == "Both"
    # Unlabeled parts still get `transform_labels`; labeled parts do not.
    @test MS.display_name(MS.replace_name(x, Dict("x1" => "x_one"), Dict("x" => "X"))) ==
          "x_one × X2"

    c = MS.CategoricalCoefName("g", "b")
    @test MS.display_name(MS.replace_name(c, Dict("g" => "Group"), Dict())) == "Group: b"
    @test MS.replace_name(c, Dict("g" => "Group", "g: b" => "B"), Dict()) == "B"
    @test MS.display_name(MS.replace_name(c, Dict("g" => "Group"), Dict("b" => "β"))) ==
          "Group: β"
    # A categorical inside an interaction: the part's full key wins over its variable key.
    xc = MS.InteractedCoefName([c, MS.CoefName("x1")])
    @test MS.display_name(MS.replace_name(xc, Dict("g" => "Group"), Dict())) ==
          "Group: b × x1"
    @test MS.display_name(MS.replace_name(xc, Dict("g" => "Group", "g: b" => "B"), Dict())) ==
          "B × x1"

    m = lm(@formula(y ~ x1 * x2 + g), df)
    out = html(modelsummary(m; labels = Dict("x1" => "T", "g" => "Group")))
    @test occursin("T × x2", out)
    @test occursin("Group: b", out)
    @test !occursin("x1 × x2", out)
    # Selectors match the names before relabeling.
    out = html(modelsummary(m; labels = Dict("x1" => "T"), keep = ["x1 & x2"]))
    @test occursin("T × x2", out)
    @test_throws "matches no name" modelsummary(m; labels = Dict("x1" => "T"), keep = ["T & x2"])

    # A non-string label may replace a whole name but not one part of it.
    bm = MS.BackendMath(raw"$\beta_1$")
    @test MS.replace_name(MS.CoefName("x1"), Dict("x1" => bm), Dict()) === bm
    @test_throws "add a label for the full name \"x1 & x2\"" modelsummary(
        m; labels = Dict("x1" => bm))
    @test_throws ArgumentError MS.replace_name(c, Dict("g" => bm), Dict())
    out = html(modelsummary(m; labels = Dict("x1" => bm, "x1 & x2" => "Both")))
    @test occursin("Both", out)
end
