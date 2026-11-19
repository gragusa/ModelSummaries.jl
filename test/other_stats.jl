using ModelSummaries
using Test
using DataFrames, FixedEffectModels, Regress
import CovarianceMatrices

const MS = ModelSummaries

@testset "Fixed-effect and cluster sections" begin
    n = 80
    x1 = sin.(1:n)
    x2 = cos.(2 .* (1:n))
    df = DataFrame(; x1, x2, y = 1 .+ x1 .- 0.5 .* x2 .+ x1 .^ 2 .* sin.(3 .* (1:n)),
        firm = repeat(1:8; inner = 10), year = repeat(1:10; outer = 8))
    fenames(entries) = [string(MS.value(first(p))) for p in entries]

    fem = reg(
        df, @formula(y ~ x1 + FixedEffectModels.fe(firm) + FixedEffectModels.fe(year)),
        FixedEffectModels.Vcov.cluster(:firm))
    fe = MS.other_stats(fem, :fe)
    @test fenames(fe) == ["firm", "year"]
    @test all(p -> first(p) isa MS.FixedEffectCoefName && MS.value(last(p)), fe)
    @test MS.other_stats(fem, :clusters) ==
          [MS.ClusterCoefName("firm") => MS.ClusterValue(8)]
    @test MS.other_stats(reg(df, @formula(y ~ x1)), :fe) === nothing
    @test MS.other_stats(reg(df, @formula(y ~ x1)), :clusters) === nothing

    # FixedEffectModels omits the common slope spanned by `fe(firm) & x1`.
    slopes = reg(df, @formula(y ~ FixedEffectModels.fe(firm) * x1 + x2))
    @test coefnames(slopes) == ["x2"]
    @test fenames(MS.other_stats(slopes, :fe)) == ["firm", "firm & x1"]
    txt = sprint(show, MIME"text/plain"(), modelsummary(slopes))
    @test occursin("x2", txt)
    @test !occursin(r"^x1 "m, txt)

    # Regress: cluster rows are the clustering dimensions of the attached estimator only.
    clname(n::String, k) = MS.ClusterCoefName(n)
    clname(::Nothing, k) = MS.UnnamedClusterCoefName(k)
    cl(pairs...) = [clname(n, k) => MS.ClusterValue(c) for (k, (n, c)) in enumerate(pairs)]
    rols0 = Regress.ols(df, @formula(y ~ x1 + Regress.fe(firm)); save_cluster = :year)
    @test fenames(MS.other_stats(rols0, :fe)) == ["firm"]
    @test MS.other_stats(rols0, :clusters) === nothing
    @test MS.other_stats(Regress.ols(df, @formula(y ~ x1)), :clusters) === nothing
    @test MS.other_stats(Regress.ols(df, @formula(y ~ x1)), :fe) === nothing
    rols = rols0 + vcov(Regress.CR1(:year))
    @test MS.other_stats(rols, :clusters) == cl("year" => 10)
    @test MS.other_stats(rols0 + vcov(Regress.CR1(df.year)), :clusters) ==
          cl(nothing => 10)
    @test MS.other_stats(
        rols0 + vcov(CovarianceMatrices.CachedCR(Regress.CR1(df.year), 1)), :clusters) ==
          cl(nothing => 10)
    df.y2 = df.x1 .+ sin.((1:n) .^ 1.7) .+ 0.5 .* cos.(0.37 .* (1:n) .^ 2)
    rols2 = Regress.ols(df, @formula(y2 ~ x1); save_cluster = [:year, :firm])
    @test MS.other_stats(rols2 + vcov(Regress.CR1(:year, :firm)), :clusters) ==
          cl("year" => 10, "firm" => 8)
    @test MS.other_stats(rols2 + vcov(Regress.CR1(df.year, df.firm)), :clusters) ==
          cl(nothing => 10, nothing => 8)
    riv0 = Regress.iv(Regress.TSLS(), df, @formula(y ~ (x1 ~ x2) + Regress.fe(firm));
        save_cluster = :year)
    @test MS.other_stats(riv0, :clusters) === nothing
    @test MS.other_stats(riv0 + vcov(Regress.CR1(:year)), :clusters) == cl("year" => 10)

    html = sprint(show, MIME"text/html"(), modelsummary(fem, rols; print_clusters = true))
    @test occursin("Firm Fixed Effects", html)
    @test occursin("Year Fixed Effects", html)
    @test occursin("Firm Clustering", html)
    @test occursin("Year Clustering", html)

    # `labels` for a fixed-effect or cluster variable keep the row's suffix.
    lab = Dict("firm" => "Company", "year" => "Calendar year")
    txt = sprint(show, MIME"text/plain"(),
        modelsummary(fem, rols; print_clusters = true, labels = lab))
    for row in ("Company Fixed Effects", "Calendar year Fixed Effects",
        "Company Clustering", "Calendar year Clustering")
        @test occursin(row, txt)
    end
    @test !occursin("Clustering Fixed Effects", txt)
    @test !occursin("Calendar year Clustering Fixed", txt)
    txt = sprint(show, MIME"text/plain"(),
        modelsummary(
            fem, rols; print_clusters = true, labels = lab, print_fe_suffix = false))
    @test occursin(r"^Company  "m, txt)
    @test !occursin("Company Clustering", txt)
    @test occursin("Company & x1 Fixed Effects",
        sprint(show, MIME"text/plain"(), modelsummary(slopes; labels = lab)))
    bm = Dict("firm" => BackendMath(raw"$\alpha_i$"))
    tex = sprint(show, MIME"text/latex"(), modelsummary(fem; print_clusters = true, labels = bm))
    @test occursin(raw"$\alpha_i$ Fixed Effects", tex)
    @test occursin(raw"$\alpha_i$ Clustering", tex)
    @test_throws ArgumentError modelsummary(fem; labels = Dict("firm" => 1))
    @test MS.replace_name(MS.FirstStageCoefName("F-statistic"),
        Dict("F-statistic" => "Kleibergen-Paap F"), Dict()) ==
          MS.FirstStageCoefName("Kleibergen-Paap F")
    @test MS.section_row_name(MS.FirstStageCoefName("F"), true) == "F First Stage"
    @test_throws ArgumentError MS.section_row_name(MS.CoefName("firm"), true)

    # A dimension given as data is named `Cluster k`, without the cluster suffix.
    rdata = rols0 + vcov(Regress.CR1(df.year))
    for mime in (MIME"text/html"(), MIME"text/latex"(), MIME"text/typst"())
        out = sprint(show, mime, modelsummary(rols, rdata; print_clusters = true))
        @test occursin("Year Clustering", out)
        @test occursin("Cluster 1", out)
        @test !occursin("Cluster 1 Clustering", out)
    end
    @test string(MS.UnnamedClusterCoefName(2)) == "Cluster 2"
    @test MS.UnnamedClusterCoefName(1) == MS.UnnamedClusterCoefName(1)
    @test MS.UnnamedClusterCoefName(1) != MS.UnnamedClusterCoefName(2)
    @test MS.UnnamedClusterCoefName(1) != MS.ClusterCoefName("Cluster 1")
    @test MS.cluster_entries(["year", nothing], [10, 8]) ==
          [MS.ClusterCoefName("year") => MS.ClusterValue(10),
        MS.UnnamedClusterCoefName(2) => MS.ClusterValue(8)]

    single = @formula(y ~ g).rhs
    @test MS.fixed_effect_entries(single, t -> false) === nothing
    @test fenames(MS.fixed_effect_entries(single, t -> true)) == ["g"]
    @test_throws "got 2 cluster names and 1 cluster counts" MS.cluster_entries(
        ["a", "b"], [3])
end
