using ModelSummaries
using Regress
using Regress: fe  # Explicitly use fe from Regress to avoid ambiguity
using DataFrames
using Test

@testset "Regress Extension" begin
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

        # Check FE section appears (case-insensitive)
        buf = IOBuffer()
        show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
        text_out = String(take!(buf))
        @test occursin(r"group"i, text_out)
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

    @testset "First Stage Section" begin
        # Test that first-stage F-statistic appears when enabled
        m = iv(TSLS(), df, @formula(y ~ x1 + (x2 ~ z)))
        ms = modelsummary(m; print_first_stage_section=true)

        buf = IOBuffer()
        show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
        text_out = String(take!(buf))

        # Check first-stage section appears with F-statistic label
        @test occursin("First Stage", text_out)

        # Test that first-stage section is disabled by default
        ms_default = modelsummary(m)
        buf_default = IOBuffer()
        show(IOContext(buf_default, :limit => false), MIME("text/plain"), ms_default)
        text_out_default = String(take!(buf_default))
        @test !occursin("First Stage", text_out_default)
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

    @testset "OLS with custom vcov" begin
        m = ols(df, @formula(y ~ x1 + x2))
        m_hc3 = m + vcov(HC3())

        # Basic table creation
        ms = modelsummary(m_hc3)
        @test size(ms, 2) == 2  # rownames + 1 model
        @test !isempty(ms.data)

        # Multiple ModelWithVcov models
        m_hc0 = m + vcov(HC0())
        m_hc1 = m + vcov(HC1())
        ms_multi = modelsummary(m_hc0, m_hc1, m_hc3)
        @test size(ms_multi, 2) == 4  # rownames + 3 models

        # Mix OLSEstimator and ModelWithVcov
        ms_mixed = modelsummary(m, m_hc3)
        @test size(ms_mixed, 2) == 3  # rownames + 2 models
    end

    @testset "OLS with FE and custom vcov" begin
        m = ols(df, @formula(y ~ x1 + fe(group)))
        m_hc3 = m + vcov(HC3())

        ms = modelsummary(m_hc3)
        @test size(ms, 2) == 2

        # Check FE section appears (case-insensitive)
        buf = IOBuffer()
        show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
        text_out = String(take!(buf))
        @test occursin(r"group"i, text_out)
    end

    @testset "IV with custom vcov" begin
        m = iv(TSLS(), df, @formula(y ~ x1 + (x2 ~ z)))
        m_hc3 = m + vcov(HC3())

        # Basic table creation
        ms = modelsummary(m_hc3)
        @test size(ms, 2) == 2
        @test !isempty(ms.data)

        # First-stage F should be recomputed with HC3
        # (We just check that it works without error)
        buf = IOBuffer()
        show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
        text_out = String(take!(buf))
        @test !isempty(text_out)
    end

    @testset "IV first stage section with custom vcov" begin
        m = iv(TSLS(), df, @formula(y ~ x1 + (x2 ~ z)))
        m_hc3 = m + vcov(HC3())

        # Test first-stage section with custom vcov (uses recomputed F_kp)
        ms = modelsummary(m_hc3; print_first_stage_section=true)

        buf = IOBuffer()
        show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
        text_out = String(take!(buf))

        # Check first-stage section appears
        @test occursin("First Stage", text_out)
    end

    @testset "Mixed model types with custom vcov" begin
        m_ols = ols(df, @formula(y ~ x1 + x2))
        m_iv = iv(TSLS(), df, @formula(y ~ x1 + (x2 ~ z)))
        m_ols_hc3 = m_ols + vcov(HC3())
        m_iv_hc3 = m_iv + vcov(HC3())

        # All four types together
        ms = modelsummary(m_ols, m_iv, m_ols_hc3, m_iv_hc3)
        @test size(ms, 2) == 5  # rownames + 4 models
    end
end
