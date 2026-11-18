using ModelSummaries
using Test
using DataFrames, FixedEffectModels, Regress

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

    rols = Regress.ols(df, @formula(y ~ x1 + Regress.fe(firm)); save_cluster = :year)
    @test fenames(MS.other_stats(rols, :fe)) == ["firm"]
    @test (MS.ClusterCoefName("year") => MS.ClusterValue(10)) in
          MS.other_stats(rols, :clusters)
    @test MS.other_stats(Regress.ols(df, @formula(y ~ x1)), :fe) === nothing

    html = sprint(show, MIME"text/html"(), modelsummary(fem, rols; print_clusters = true))
    @test occursin("Firm Fixed Effects", html)
    @test occursin("Year Fixed Effects", html)
    @test occursin("Firm Clustering", html)
    @test occursin("Year Clustering", html)

    single = @formula(y ~ g).rhs
    @test MS.fixed_effect_entries(single, t -> false) === nothing
    @test fenames(MS.fixed_effect_entries(single, t -> true)) == ["g"]
    @test_throws "got 2 cluster names and 1 cluster counts" MS.cluster_entries(
        ["a", "b"], [3])
end
