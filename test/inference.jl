using ModelSummaries
using Test
using DataFrames, GLM, FixedEffectModels, Regress, CovarianceMatrices, StatsAPI,
      Distributions
using StatsAPI: RegressionModel
using GLM: CoefTable

const MS = ModelSummaries

# p-values, test statistics, and confidence intervals as the model package reports them,
# keyed by coefficient name (a coeftable may order its rows differently from `coef`).
function package_inference(m; level = 0.95)
    ct = coeftable(m)
    rows = Dict(nm => i for (i, nm) in pairs(ct.rownms))
    nms = string.(coefnames(m))
    pv = [ct.cols[ct.pvalcol][rows[nm]] for nm in nms]
    tcol = findfirst(in(("t", "z", "t-stat")), ct.colnms)
    ts = [ct.cols[tcol][rows[nm]] for nm in nms]
    (; pv, ts, ci = confint(m; level))
end

@testset "Inference comes from coeftable and confint" begin
    n = 80
    x1 = sin.(1:n)
    x2 = cos.(2 .* (1:n))
    w = x1 .+ 0.5 .* cos.(5 .* (1:n))
    y = 1 .+ x1 .- 0.5 .* x2 .+ x1 .^ 2 .* sin.(3 .* (1:n))
    df = DataFrame(; x1, x2, w, y, b = Int.(y .> 1), firm = repeat(1:8; inner = 10))

    mreg = Regress.ols(df, @formula(y ~ x1 + x2); save_cluster = :firm)
    models = [
        "GLM OLS" => lm(@formula(y ~ x1 + x2), df),
        "GLM logit" => glm(@formula(b ~ x1 + x2), df, Binomial(), LogitLink()),
        "FEM" => reg(df, @formula(y ~ x1 + x2)),
        "FEM fe + cluster" => reg(df, @formula(y ~ x1 + x2 + FixedEffectModels.fe(firm)),
            FixedEffectModels.Vcov.cluster(:firm)),
        "FEM IV" => reg(df, @formula(y ~ x2 + (x1 ~ w))),
        "Regress OLS" => mreg,
        "Regress OLS + HC3" => mreg + vcov(HC3()),
        "Regress OLS + CR1" => mreg + vcov(CR1(:firm))
    ]
    for (name, m) in models
        @testset "$name" begin
            ref = package_inference(m; level = 0.9)
            for k in eachindex(coef(m))
                cv = MS.CoefValue(m, k)
                @test MS.value(cv) == coef(m)[k]
                @test cv.pvalue == ref.pv[k]
                @test MS.value(TStat(m, k)) == ref.ts[k]
                @test collect(MS.value(ConfInt(m, k; level = 0.9))) == ref.ci[k, :]
            end
            @test modelsummary(m; below_statistic = TStat, stars = true) isa
                  MS.SummaryTables.Table
        end
    end

    # The logit's p-values are z-tests, not t-tests with dof_residual degrees of freedom.
    logit = last(models[2])
    z = coef(logit) ./ stderror(logit)
    @test MS._pvalue(logit) ≈ 2 .* ccdf.(Normal(), abs.(z))
    @test !(MS._pvalue(logit) ≈ 2 .* ccdf.(TDist(dof_residual(logit)), abs.(z)))

    # FixedEffectModels and Regress list the intercept last in coeftable.
    fem = last(models[3])
    @test last(coeftable(fem).rownms) == "(Intercept)"
    @test first(coefnames(fem)) == "(Intercept)"
    @test MS._teststat(fem) ≈ coef(fem) ./ stderror(fem)

    @testset "p-value note" begin
        ols, fem_cl = last(models[1]), last(models[4])
        t = modelsummary(ols, logit, fem_cl; pvalue_note = true, footnotes = ["Source: x"])
        note = "p-values: (1) t($(Int(dof_residual(ols)))); (2) Normal; \
                (3) t($(dof_residual(fem_cl)))"
        @test t.footnotes == ["Source: x", note]
        @test modelsummary(ols; pvalue_note = true).footnotes ==
              ["p-values: t($(Int(dof_residual(ols))))"]
        @test isempty(modelsummary(ols).footnotes)
        @test MS.pvalue_note_text([mreg + vcov(HC3())]) ==
              "p-values: t($(dof_residual(mreg)))"
    end
end

struct FakeModel <: RegressionModel
    ct::CoefTable
    b::Vector{Float64}
    nms::Vector{String}
end
StatsAPI.coef(m::FakeModel) = m.b
StatsAPI.coefnames(m::FakeModel) = m.nms
StatsAPI.coeftable(m::FakeModel) = m.ct

function fake(; pvalcol = 3, teststatcol = 2, rownms = ["a", "b"], est = [1.0, 2.0],
        tstat = [2.0, 3.0], dist = TDist(20))
    p = 2 .* ccdf.(dist, abs.(tstat))
    ct = CoefTable([est, tstat, p], ["Coef.", "t", "P"], rownms, pvalcol, teststatcol)
    FakeModel(ct, [1.0, 2.0], ["a", "b"])
end
MS.reference_distribution(::FakeModel) = TDist(20)

struct NoDistModel <: RegressionModel end

@testset "Inference errors" begin
    @test MS.pvalue_note_text([fake()]) == "p-values: t(20)"
    @test MS._pvalue(fake(rownms = ["b", "a"], est = [2.0, 1.0])) ≈
          reverse(2 .* ccdf.(TDist(20), [2.0, 3.0]))

    @test_throws "are not two-sided tests against t(20)" MS.pvalue_note_text(
        [fake(dist = Normal())])
    @test_throws "does not mark its p-value (`pvalcol`) column" MS._pvalue(fake(pvalcol = 0))
    @test_throws "does not mark its test-statistic (`teststatcol`) column" MS._teststat(
        fake(teststatcol = 0))
    @test_throws "are not a permutation of its coefficient names" MS._pvalue(
        fake(rownms = ["a", "c"]))
    @test_throws "does not reproduce `coef`" MS._pvalue(fake(est = [1.0, 2.5]))

    ct = coeftable(fake(teststatcol = 0))
    @test MS.with_teststatcol(ct, "t").teststatcol == 2
    @test_throws "has no column named \"z\"" MS.with_teststatcol(ct, "z")
    @test_throws "marks column 2 (\"t\") as the test statistic, not \"P\"" MS.with_teststatcol(
        coeftable(fake()), "P")

    @test_throws "no `ModelSummaries.reference_distribution` method for NoDistModel" MS.reference_distribution(
        NoDistModel())
end
