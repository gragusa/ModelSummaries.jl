using ModelSummaries
using Test
using GLM, DataFrames, StatsAPI
using FixedEffectModels: reg, fe
using Distributions: FDist, ccdf

const SM = ModelSummaries.StatsModels

struct FailingModel <: StatsAPI.RegressionModel end
StatsAPI.nobs(::FailingModel) = error("nobs failed inside the model package")

struct NoNobsModel <: StatsAPI.RegressionModel end
ModelSummaries.applies(::Type{Nobs}, ::NoNobsModel) = false

struct MisnamedModel <: StatsAPI.RegressionModel
    f::SM.FormulaTerm
end
SM.formula(m::MisnamedModel) = m.f
StatsAPI.coef(::MisnamedModel) = [1.0]

@testset "Statistics: blank only when declared inapplicable" begin
    df = DataFrame(y = randn(60), x = randn(60), b = rand(0:1, 60))
    ols = lm(@formula(y ~ x), df)
    logit = glm(@formula(b ~ x), df, Binomial(), LogitLink())

    mat = ModelSummaries.combine_statistics((ols, logit), [Nobs, R2, FStat, R2Within])
    # Column 1 holds the labels; columns 2 and 3 the OLS and logit values.
    @test ModelSummaries.value(mat[1, 2]) == 60
    @test ModelSummaries.value(mat[2, 2]) ≈ r2(ols)
    @test mat[2, 3] === nothing
    @test mat[3, 2] isa FStat
    @test mat[3, 3] === nothing
    @test mat[4, 2] === nothing
    @test mat[4, 3] === nothing
    @test modelsummary(ols, logit; regression_statistics = [Nobs, R2]) isa
          ModelSummaries.SummaryTables.Table

    @test !ModelSummaries.applies(R2, logit)
    @test ModelSummaries.applies(R2, ols)
    @test ModelSummaries.applies(R2McFadden, logit)

    mat = ModelSummaries.combine_statistics((NoNobsModel(),), [Nobs])
    @test mat[1, 2] === nothing
end

@testset "Default statistics come from the models" begin
    df = DataFrame(y = randn(60), x = randn(60), b = rand(0:1, 60), g = repeat(1:6, 10))
    ols = lm(@formula(y ~ x), df)
    logit = glm(@formula(b ~ x), df, Binomial(), LogitLink())
    fem = reg(df, @formula(y ~ x + fe(g)))

    @test ModelSummaries.default_regression_statistics((ols,)) == [Nobs, R2]
    @test ModelSummaries.default_regression_statistics((logit,)) == [Nobs, R2McFadden]
    @test ModelSummaries.default_regression_statistics((ols, logit)) ==
          [Nobs, R2, R2McFadden]
    @test ModelSummaries.default_regression_statistics((ols, fem)) == [Nobs, R2, R2Within]

    html(t) = sprint(show, MIME"text/html"(), t)
    @test html(modelsummary(ols, logit)) ==
          html(modelsummary(ols, logit; regression_statistics = [Nobs, R2, R2McFadden]))
    @test occursin("Pseudo", html(modelsummary(logit)))
    @test occursin("Within", html(modelsummary(fem)))
    @test !occursin("Pseudo", html(modelsummary(ols)))
end

@testset "Linear-model F test matches GLM.ftest" begin
    t = 1:40
    df = DataFrame(x = sin.(t), z = cos.(t) .^ 2)
    df.y = 1 .+ 0.3 .* df.x .+ 0.2 .* df.z .+ 0.5 .* sin.(3 .* t)
    for f in (@formula(y ~ x), @formula(y ~ x + z))
        m = lm(f, df)
        ref = ftest(m.model)
        @test ModelSummaries.applies(FStat, m)
        @test ModelSummaries.value(FStat(m)) ≈ ref.fstat
        @test ModelSummaries.value(FStatPValue(m)) ≈ ref.pval
    end

    # Without an intercept GLM's null model has no predictor, so F tests every coefficient.
    m0 = lm(@formula(y ~ 0 + x + z), df)
    rss, n = deviance(m0), nrow(df)
    F0 = ((sum(abs2, df.y) - rss) / 2) / (rss / (n - 2))
    @test ModelSummaries.value(@test_logs (:warn, r"null model") FStat(m0)) ≈ F0
    @test ModelSummaries.value(@test_logs (:warn, r"null model") match_mode=:any FStatPValue(m0)) ≈
          ccdf(FDist(2, n - 2), F0)

    m1 = lm(@formula(y ~ 1), df)
    @test !ModelSummaries.applies(FStat, m1)
    @test !ModelSummaries.applies(FStatPValue, m1)
    @test ModelSummaries.combine_statistics((m1,), [FStat])[1, 2] === nothing
end

@testset "Statistics: errors propagate" begin
    @test_throws "nobs failed inside the model package" Nobs(FailingModel())
    @test_throws "nobs failed inside the model package" ModelSummaries.combine_statistics(
        (FailingModel(),), [Nobs])
    @test_throws "the regression statistic FStat is not available for models of type FailingModel" FStat(FailingModel())
    @test_throws "ModelSummaries.applies(::Type{R2Within}, ::FailingModel) = false" R2Within(FailingModel())
end

@testset "Coefficient names must match the coefficients" begin
    df = DataFrame(y = randn(10), x = randn(10))
    f = SM.apply_schema(@formula(y ~ 1 + x), SM.schema(df))
    m = MisnamedModel(f)
    @test_throws "yields 2 coefficient names but the model has 1 coefficients" ModelSummaries._coefnames(m)
    @test string(ModelSummaries._responsename(m)) == "y"
end
