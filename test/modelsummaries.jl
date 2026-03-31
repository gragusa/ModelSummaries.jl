using ModelSummaries
using FixedEffectModels, GLM, RDatasets, Test
using DataFrames
using SummaryTables: Table

df = RDatasets.dataset("datasets", "iris")
df[!, :isSmall] = df[!, :SepalWidth] .< 2.9
df[!, :isWide] = df[!, :SepalWidth] .> 2.5

# FixedEffectModels.jl
rr1 = reg(df, @formula(SepalLength ~ SepalWidth))
rr2 = reg(df, @formula(SepalLength ~ SepalWidth + PetalLength + fe(Species)))
rr3 = reg(df, @formula(SepalLength ~
                       SepalWidth + PetalLength + PetalWidth + fe(Species) + fe(isSmall)))
rr4 = reg(df, @formula(SepalWidth ~ SepalLength + PetalLength + PetalWidth + fe(Species)))
rr5 = reg(df, @formula(SepalWidth ~ SepalLength + (PetalLength ~ PetalWidth) + fe(Species)))

# GLM.jl
lm1 = fit(LinearModel, @formula(SepalLength ~ SepalWidth), df)
lm2 = fit(LinearModel, @formula(SepalLength ~ SepalWidth + PetalWidth), df)
lm3 = fit(LinearModel, @formula(SepalLength ~ SepalWidth * PetalWidth), df)

dobson = DataFrame(Counts = [18.0, 17, 15, 20, 10, 20, 25, 13, 12],
    Outcome = repeat(["A", "B", "C"], outer = 3),
    Treatment = repeat(["a", "b", "c"], inner = 3))
gm1 = fit(GeneralizedLinearModel, @formula(Counts ~ 1 + Outcome), dobson, Poisson())

@testset "Return type" begin
    @test modelsummary(rr1) isa Table
    @test modelsummary(rr1, rr2) isa Table
end

@testset "LaTeX output" begin
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(rr1, rr2))
    out = String(take!(buf))
    @test occursin("\\begin{table}", out)
    @test occursin("\\toprule", out)
    @test occursin("\\bottomrule", out)
    @test occursin("SepalWidth", out)
    @test occursin("(Intercept)", out)
end

@testset "Typst output" begin
    buf = IOBuffer()
    show(buf, MIME"text/typst"(), modelsummary(rr1))
    out = String(take!(buf))
    @test occursin("#table", out)
    @test occursin("SepalWidth", out)
end

@testset "HTML output" begin
    buf = IOBuffer()
    show(buf, MIME"text/html"(), modelsummary(lm1, lm2))
    out = String(take!(buf))
    @test occursin("<table", out)
    @test occursin("SepalWidth", out)
end

@testset "Stars" begin
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(rr1, rr2; stars=true))
    out = String(take!(buf))
    @test occursin("\\textsuperscript{", out)
end

@testset "Below statistic options" begin
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(lm1; below_statistic=StdError))
    out = String(take!(buf))
    @test occursin("(0.", out)

    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(lm1; below_statistic=ConfInt))
    out = String(take!(buf))
    @test occursin(",", out)

    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(lm1; below_statistic=nothing))
    out = String(take!(buf))
    @test !occursin("(0.", out)
end

@testset "Keep, drop, order" begin
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(lm1, lm2; keep=["SepalWidth"]))
    out = String(take!(buf))
    @test occursin("SepalWidth", out)
    @test !occursin("(Intercept)", out)

    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(lm1, lm2; drop=["(Intercept)"]))
    out = String(take!(buf))
    @test !occursin("(Intercept)", out)
    @test occursin("SepalWidth", out)
end

@testset "Regression statistics" begin
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(lm1;
        regression_statistics=[Nobs, R2, AdjR2, AIC, BIC]))
    out = String(take!(buf))
    @test occursin("N", out)
    @test occursin("Adjusted", out)
    @test occursin("AIC", out)
    @test occursin("BIC", out)
end

@testset "Labels" begin
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(lm1;
        labels=Dict("SepalWidth" => "Sepal Width (cm)")))
    out = String(take!(buf))
    @test occursin("Sepal Width (cm)", out)
end

@testset "Groups" begin
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(lm1, lm2;
        groups=["Base", "Extended"]))
    out = String(take!(buf))
    @test occursin("Base", out)
    @test occursin("Extended", out)
end

@testset "Fixed effects" begin
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(rr2, rr3))
    out = String(take!(buf))
    @test occursin("Species", out)
    @test occursin("Yes", out)
end

@testset "Estimator section" begin
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(lm1, gm1; print_estimator_section=true))
    out = String(take!(buf))
    @test occursin("Estimator", out)
    @test occursin("OLS", out)
    @test occursin("Poisson", out)
end

@testset "File output" begin
    mktempdir() do dir
        texfile = joinpath(dir, "test.tex")
        modelsummary(lm1, lm2; file=texfile)
        @test isfile(texfile)
        @test occursin("\\begin{table}", read(texfile, String))

        htmlfile = joinpath(dir, "test.html")
        modelsummary(lm1, lm2; file=htmlfile)
        @test isfile(htmlfile)
        @test occursin("<table", read(htmlfile, String))

        typfile = joinpath(dir, "test.typ")
        modelsummary(lm1, lm2; file=typfile)
        @test isfile(typfile)
        @test occursin("#table", read(typfile, String))
    end
end

@testset "Mixed model types" begin
    @test modelsummary(rr1, rr2, lm1, lm2, gm1) isa Table
end

@testset "Extralines" begin
    comments = ["Specification", "Baseline", "Preferred"]
    buf = IOBuffer()
    show(buf, MIME"text/latex"(), modelsummary(rr1, rr2; extralines=[comments]))
    out = String(take!(buf))
    @test occursin("Specification", out)
    @test occursin("Baseline", out)
end

@testset "Symbol aliases" begin
    @test modelsummary(lm1; below_statistic=:se) isa Table
    @test modelsummary(lm1; below_statistic=:tstat) isa Table
    @test modelsummary(lm1; below_statistic=:none) isa Table
    @test modelsummary(lm1; regression_statistics=[:nobs, :r2, :adjr2]) isa Table
end
