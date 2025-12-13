using ModelSummaries
using MetricsLinearModels
using MetricsLinearModels: fe  # Explicitly use fe from MetricsLinearModels to avoid ambiguity
using DataFrames
using Test

@testset "MetricsLinearModels Extension" begin
    # Create test data
    df = DataFrame(
        y = randn(100),
        x1 = randn(100),
        x2 = randn(100),
        z = randn(100),  # instrument
        group = rand(1:5, 100)
    )

    @testset "OLS without FE" begin
        m = ols(df, @formula(y ~ x1 + x2))
        ms = modelsummary(m)
        @test size(ms, 2) == 2  # rownames + 1 model
        @test !isempty(ms.data)

        # Test LaTeX output
        buf = IOBuffer()
        show(IOContext(buf, :limit => false), MIME("text/latex"), ms)
        latex_out = String(take!(buf))
        @test occursin("tabular", latex_out)
    end

    @testset "OLS with FE" begin
        m = ols(df, @formula(y ~ x1 + fe(group)))
        ms = modelsummary(m)
        @test size(ms, 2) == 2

        # Check FE section appears
        buf = IOBuffer()
        show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
        text_out = String(take!(buf))
        @test occursin("group", text_out)
    end

    @testset "Multiple OLS models" begin
        m1 = ols(df, @formula(y ~ x1))
        m2 = ols(df, @formula(y ~ x1 + x2))
        m3 = ols(df, @formula(y ~ x1 + fe(group)))

        ms = modelsummary(m1, m2, m3)
        @test size(ms, 2) == 4  # rownames + 3 models
    end

    @testset "IV model (TSLS)" begin
        # Simple IV: x2 is endogenous, z is instrument
        m = iv(TSLS(), df, @formula(y ~ x1 + (x2 ~ z)))
        ms = modelsummary(m)
        @test size(ms, 2) == 2

        # Check IV-specific statistics appear (F_kp)
        buf = IOBuffer()
        show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
        text_out = String(take!(buf))
        # Should have first-stage F in default stats
    end

    @testset "Mixed OLS and IV" begin
        m1 = ols(df, @formula(y ~ x1 + x2))
        m2 = iv(TSLS(), df, @formula(y ~ x1 + (x2 ~ z)))

        ms = modelsummary(m1, m2)
        @test size(ms, 2) == 3
    end

    @testset "Custom vcov" begin
        m = ols(df, @formula(y ~ x1 + x2))

        # With HC3
        ms = modelsummary(m + vcov(HC3()))
        @test !isempty(ms.data)
    end
end
