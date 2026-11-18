using ModelSummaries
using Test
using DataFrames, GLM, Regress, CovarianceMatrices, StatsAPI

const MS = ModelSummaries

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
    @test MS.value(VcovType(m + vcov(CR1(:firm)))) == "CR1"

    @test modelsummary(m, mh; regression_statistics = [Nobs, R2, VcovType]) isa
          MS.SummaryTables.Table

    # `+` for a model type belongs to the package that owns the type or `VcovSpec`.
    ext = Base.get_extension(MS, :ModelSummariesCovarianceMatricesExt)
    @test ext !== nothing
    @test !any(meth -> parentmodule(meth) in (MS, ext), methods(+))
end
