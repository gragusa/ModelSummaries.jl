using ModelSummaries
using Test
using GLM, DataFrames, StatsAPI

const SM = ModelSummaries.StatsModels

# A model with coefficients but no way to standardize them.
struct PlainModel <: StatsAPI.RegressionModel end
function SM.formula(::PlainModel)
    SM.FormulaTerm(SM.term(:y),
        SM.MatrixTerm((SM.InterceptTerm{true}(), SM.term(:x))))
end
StatsAPI.coef(::PlainModel) = [1.0, 2.0]
StatsAPI.stderror(::PlainModel) = [0.1, 0.2]
StatsAPI.dof_residual(::PlainModel) = 10
StatsAPI.nobs(::PlainModel) = 12
StatsAPI.coefnames(::PlainModel) = ["(Intercept)", "x"]
function StatsAPI.coeftable(::PlainModel)
    GLM.CoefTable([[1.0, 2.0], [0.1, 0.2], [10.0, 10.0], [0.0, 0.0]],
        ["Coef.", "Std. Error", "t", "Pr(>|t|)"], ["(Intercept)", "x"], 4, 3)
end

@testset "Input validation" begin
    df = DataFrame(y = randn(60), x1 = randn(60), x2 = randn(60), b = rand(0:1, 60))
    m1 = lm(@formula(y ~ x1), df)
    m2 = lm(@formula(y ~ x1 + x2), df)
    logit = glm(@formula(b ~ x1), df, Binomial(), LogitLink())

    @testset "keep / drop / order" begin
        @test_throws "keep: \"x3\" matches no name" modelsummary(m1, m2; keep = ["x3"])
        @test_throws "drop: \"X1\" matches no name" modelsummary(m1, m2; drop = ["X1"])
        @test_throws "order: r\"^z\" matches no name" modelsummary(m1, m2; order = [r"^z"])
        @test_throws "available names: \"(Intercept)\", \"x1\", \"x2\"" modelsummary(
            m1, m2; keep = ["x3"])
        @test_throws "index 4 is out of range for 3 names" modelsummary(m1, m2; keep = [4])
        @test_throws "index range 2:5 is out of range" modelsummary(m1, m2; keep = [2:5])
        @test_throws "Symbol first not recognized" modelsummary(m1, m2; keep = [:first])

        # A name that exists in some model is valid even if `keep` already removed it.
        t = modelsummary(m1, m2; keep = ["x1"], drop = ["x2"], order = ["(Intercept)"])
        @test t isa ModelSummaries.SummaryTables.Table
        t = modelsummary(m1, m2; keep = [r"x"])
        @test t isa ModelSummaries.SummaryTables.Table
    end

    @testset "file extensions" begin
        dir = mktempdir()
        @test_throws "unsupported extension \".pdf\"; use one of .tex, .html, .htm, .typ, .docx" modelsummary(
            m1; file = joinpath(dir, "t.pdf"))
        @test_throws "unsupported extension \"\"" modelsummary(m1; file = joinpath(dir, "t"))
        # Rejected before anything is written.
        @test !isfile(joinpath(dir, "t.pdf"))

        for (ext, needle) in ((".tex", "\\begin{table}"), (".html", "<table"),
            (".HTM", "<table"), (".typ", "table("))
            f = joinpath(dir, "t" * ext)
            modelsummary(m1, m2; file = f)
            @test occursin(needle, read(f, String))
        end

        f = joinpath(dir, "t.docx")
        modelsummary(m1, m2; file = f)
        # A .docx file is a ZIP archive: it starts with the "PK\x03\x04" signature.
        @test read(f, 4) == UInt8[0x50, 0x4b, 0x03, 0x04]
    end

    @testset "standardize_coef" begin
        @test modelsummary(m1, logit; standardize_coef = true) isa
              ModelSummaries.SummaryTables.Table
        @test_throws "the coefficients of model 2 (PlainModel) cannot be standardized" modelsummary(
            m1, PlainModel(); standardize_coef = true)
        # Asking only for the models that support it is fine.
        @test modelsummary(m1, PlainModel(); standardize_coef = [true, false],
            regression_statistics = [Nobs]) isa
              ModelSummaries.SummaryTables.Table
        @test_throws "standardize_coef has 1 entries for 2 models" modelsummary(
            m1, m2; standardize_coef = [true])
    end

    @testset "keyword values" begin
        @test_throws "align = :x is not recognized" modelsummary(m1; align = :x)
        @test_throws "header_align = :x is not recognized" modelsummary(m1; header_align = :x)
        @test_throws "below_statistic = :pvalue is not recognized" modelsummary(
            m1; below_statistic = :pvalue)
        @test_throws "transform_labels = :tex is not recognized" modelsummary(
            m1; transform_labels = :tex)
        @test_throws "confidence level must be in (0, 1), got 95" modelsummary(
            m1; below_statistic = ConfInt, confint_level = 95)
        @test_throws ArgumentError ModelSummaries.significance_stars(0.02; breaks = [
            0.05, 0.01])
    end
end
