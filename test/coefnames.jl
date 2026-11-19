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

    # A part label may be a string or a BackendMath; any other value must label the whole name.
    bm = MS.BackendMath(raw"$\beta_1$")
    @test MS.replace_name(MS.CoefName("x1"), Dict("x1" => bm), Dict()) === bm
    @test_throws "add a label for the full name \"x1 & x2\"" modelsummary(
        m; labels = Dict("x1" => 1.5))
    @test_throws ArgumentError MS.replace_name(c, Dict("g" => 1.5), Dict())
    out = html(modelsummary(m; labels = Dict("x1" => bm, "x1 & x2" => "Both")))
    @test occursin("Both", out)

    cb = MS.replace_name(c, Dict("g" => bm), Dict())
    @test cb == MS.CategoricalCoefName(bm, "b")
    @test MS.display_name(cb) isa MS.SummaryTables.Concat
    @test string(cb) == "β₁: b"
    xb = MS.replace_name(x, Dict("x1" => bm), Dict())
    @test MS.display_name(xb) isa MS.SummaryTables.Concat
    @test string(xb) == "β₁ & x2"
end

@testset "BackendMath part labels in every backend" begin
    df = DataFrame(y = sin.(1:60), x1 = cos.(1:60), x2 = sin.(2 .* (1:60)),
        g = repeat(["a", "b_1", "c"], 20))
    m = lm(@formula(y ~ x1 * x2 + g * x1), df)
    labels = Dict("x1" => MS.BackendMath(raw"$\beta_1$"), "x2" => "x_2 & <z>",
        "g" => MS.BackendMath(raw"$\gamma$"))
    t = modelsummary(m; labels)
    out(mime) = sprint(show, mime, t)

    # Plain-string parts are escaped; BackendMath parts are written as given.
    txt = out(MIME"text/plain"())
    @test occursin("β₁ × x_2 & <z>", txt)
    @test occursin("γ: b_1 × β₁", txt)
    h = out(MIME"text/html"())
    @test occursin("<i>&beta;<sub>1</sub></i> × x_2 &amp; &lt;z&gt;", h)
    @test occursin("<i>&gamma;</i>: b_1 × <i>&beta;<sub>1</sub></i>", h)
    tex = out(MIME"text/latex"())
    @test occursin(raw"$\beta_1$ $\times$ x\_2 \& <z>", tex)
    @test occursin(raw"$\gamma$: b\_1 $\times$ $\beta_1$", tex)
    typ = out(MIME"text/typst"())
    @test occursin(raw"""[$beta_1$#" × "#"x_2 & <z>"]""", typ)
    @test occursin(raw"""[$gamma$#": "#"b_1"#" × "$beta_1$]""", typ)
    mktempdir() do dir
        f = joinpath(dir, "t.docx")
        modelsummary(m; labels, file = f)
        @test filesize(f) > 0
    end
end
