using ModelSummaries
using Test
using DataFrames, GLM, Regress, CovarianceMatrices, StatsAPI
using FixedEffectModels: reg, Vcov

const MS = ModelSummaries

# A model whose `vcov` is a plain matrix, with no record of how it was computed.
struct PlainVcovModel <: StatsAPI.RegressionModel end
StatsAPI.vcov(::PlainVcovModel) = [1.0;;]

@testset "Covariance estimators come from the model" begin
    n = 80
    x1 = sin.(1:n)
    x2 = cos.(2 .* (1:n))
    df = DataFrame(; x1, x2, y = 1 .+ x1 .- 0.5 .* x2 .+ x1 .^ 2 .* sin.(3 .* (1:n)),
        firm = repeat(1:8; inner = 10))
    f = @formula(y ~ x1 + x2)
    m = Regress.ols(df, f; save_cluster = :firm)
    mh = m + vcov(HC3())
    @test stderror(mh) != stderror(m)

    for k in eachindex(coef(mh))
        @test MS.value(StdError(mh, k)) ≈ stderror(mh)[k]
        @test MS.value(TStat(mh, k)) ≈ coef(mh)[k] / stderror(mh)[k]
        @test collect(MS.value(ConfInt(mh, k; level = 0.9))) ≈
              confint(mh; level = 0.9)[k, :]
    end
    @test MS.value(FStat(mh)) ≈ mh.F
    @test MS.value(FStatPValue(mh)) ≈ mh.p

    @test MS.value(VcovType(m)) == "HC1"
    @test MS.value(VcovType(mh)) == "HC3"
    @test MS.value(VcovType(m + vcov(Bartlett(3)))) == "Bartlett(3)"
    @test MS.value(VcovType(m + vcov(Bartlett(2.5)))) == "Bartlett(2.5)"
    @test MS.value(VcovType(m + vcov(CR1(:firm)))) == "CR1"

    # A data-driven bandwidth is reported as selected for the standard errors shown.
    ma = m + vcov(Bartlett{Andrews}())
    bw = bandwidth(vcov(ma))
    @test bw > 0
    @test MS.value(VcovType(ma)) == "Bartlett(Andrews), bw: $(round(bw; digits = 2))"
    @test MS.vcov_type_name(Parzen{NeweyWest}()) == "Parzen(NeweyWest)"
    @test MS.vcov_type_name(Bartlett{Andrews}(), PlainVcovModel()) == "Bartlett(Andrews)"
    @test MS.vcov_type_name(HC3(), PlainVcovModel()) == "HC3"

    @test modelsummary(m, mh; regression_statistics = [Nobs, R2, VcovType]) isa
          MS.SummaryTables.Table

    # `+` for a model type belongs to the package that owns the type or `VcovSpec`.
    ext = Base.get_extension(MS, :ModelSummariesCovarianceMatricesExt)
    @test ext !== nothing
    @test !any(meth -> parentmodule(meth) in (MS, ext), methods(+))
end

struct NoVcovModel <: StatsAPI.RegressionModel end

@testset "Std. Error row names the estimator of each model type" begin
    n = 60
    df = DataFrame(; x = sin.(1:n), y = cos.(1:n) .+ sin.(1:n),
        b = isodd.(1:n) .| (sin.(1:n) .> 0.5), g = repeat(1:6; inner = 10))
    ols = lm(@formula(y ~ x), df)
    logit = glm(@formula(b ~ x), df, Binomial(), GLM.LogitLink())
    gauss = glm(@formula(y ~ x), df, Normal(), IdentityLink())
    @test MS.value(VcovType(ols)) == "IID"
    @test MS.value(VcovType(ols.model)) == "IID"
    @test MS.value(VcovType(logit)) == "Information-based"
    @test MS.value(VcovType(gauss)) == "Information-based"

    fe_simple = reg(df, @formula(y ~ x), Vcov.simple())
    fe_robust = reg(df, @formula(y ~ x), Vcov.robust())
    fe_cluster = reg(df, @formula(y ~ x), Vcov.cluster(:g))
    @test MS.value(VcovType(fe_simple)) == "IID"
    @test MS.value(VcovType(fe_robust)) == "HC1"
    @test MS.value(VcovType(fe_cluster)) == "CR1"

    mat = MS.combine_statistics((ols, logit, fe_robust, fe_cluster), [VcovType])
    @test [MS.value(mat[1, j]) for j in 2:5] == ["IID", "Information-based", "HC1", "CR1"]
    @test modelsummary(ols, logit, fe_cluster; regression_statistics = [Nobs, VcovType]) isa
          MS.SummaryTables.Table

    @test_throws "the regression statistic VcovType is not available for models of type NoVcovModel" VcovType(NoVcovModel())
end
