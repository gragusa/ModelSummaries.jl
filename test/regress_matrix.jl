using ModelSummaries
using Test
using DataFrames, Regress
import CovarianceMatrices
using StatsAPI: coef, stderror

const MS = ModelSummaries

text(t) = sprint(show, MIME"text/plain"(), t)

@testset "Regress fits from matrices" begin
    n = 80
    x1 = sin.(1:n)
    z = cos.(2 .* (1:n))
    x = z .+ 0.3 .* x1 .+ 0.5 .* cos.((1:n) .^ 1.3)
    y = 1 .+ x .- 0.5 .* x1 .+ sin.((1:n) .^ 1.7)
    firm = repeat(1:8; inner = 10)
    year = repeat(1:10; outer = 8)
    df = DataFrame(; y, x, x1, z, firm, year)

    # OLS: names from `coefnames`, "(Intercept)" sharing the formula fits' intercept row.
    of = Regress.ols(df, @formula(y ~ x1 + x))
    om = Regress.ols(hcat(ones(n), x1, x), y; coefnames = ["(Intercept)", "x1", "x"])
    @test MS._coefnames(om) == MS._coefnames(of)
    @test MS._coefnames(om)[1] isa MS.InterceptCoefName
    @test MS._coefnames(Regress.ols(hcat(x1, x), y)) ==
          [MS.CoefName("x1"), MS.CoefName("x2")]
    @test MS.RegressionType(om) == MS.RegressionType(of)
    @test MS.default_regression_statistics(om) == [Nobs, R2]
    @test MS.applies(R2Within, om) == false
    @test MS.applies(FStatIV, om) == false
    @test MS.other_stats(om, :fe) === nothing
    @test MS.other_stats(om, :clusters) === nothing
    @test MS.other_stats(om, :first_stage) === nothing

    t = modelsummary(of, om; print_estimator_section = true, pvalue_note = true,
        regression_statistics = [Nobs, R2, VcovType])
    out = text(t)
    @test count("(Intercept)", out) == 1
    @test occursin("OLS", out)
    @test occursin("HC1", out)
    @test occursin("(1) t(77); (2) t(77)", out)
    # The response name is empty: only the formula fit's cell names it.
    @test count(r"\by\b", out) == 1
    @test text(modelsummary(om; labels = Dict("x" => "Treatment"), keep = ["x"])) |>
          s -> occursin("Treatment", s) && !occursin("x1", s)

    # IV: estimator row, no first-stage F (Regress stores none for matrix fits).
    ivf = Regress.iv(Regress.TSLS(), df, @formula(y ~ x1 + (x ~ z)))
    ivm = Regress.iv(Regress.TSLS(), hcat(ones(n), x1, z), hcat(ones(n), x1, x), y;
        coefnames = ["(Intercept)", "x1", "x"])
    @test coef(ivm) ≈ coef(ivf)
    @test MS._coefnames(ivm) == MS._coefnames(ivf)
    @test MS.RegressionType(ivm) == MS.RegressionType(ivf)
    @test MS.RegressionType(ivm).is_iv
    @test MS.default_regression_statistics(ivm) == [Nobs, R2]
    @test_throws "Regress does not store the first-stage F of a IVMatrixEstimator" FStatIV(ivm)
    @test_throws "leave FStatIVPValue out of `regression_statistics`" FStatIVPValue(ivm)
    @test_throws "print_first_stage_section = false" MS.other_stats(ivm, :first_stage)
    out = text(modelsummary(om, ivm; print_estimator_section = true))
    @test occursin("OLS", out) && occursin("IV", out)
    # A formula IV fit's default statistics include the first-stage F, which the matrix
    # fit cannot report.
    @test_throws "first-stage F of a IVMatrixEstimator" modelsummary(ivf, ivm)
    @test_throws "first-stage F of a IVMatrixEstimator" modelsummary(ivf, ivm;
        regression_statistics = [Nobs], print_first_stage_section = true)
    @test occursin("(Intercept)",
        text(modelsummary(ivf, ivm; regression_statistics = [Nobs, R2])))

    # Clusters given as data: `Cluster k` with the group count.
    for m in (om, ivm)
        mc = m + vcov(Regress.CR1(year))
        @test MS.other_stats(mc, :clusters) ==
              [MS.UnnamedClusterCoefName(1) => MS.ClusterValue(10)]
        @test MS.other_stats(m + vcov(Regress.CR1(year, firm)), :clusters) ==
              [MS.UnnamedClusterCoefName(1) => MS.ClusterValue(10),
            MS.UnnamedClusterCoefName(2) => MS.ClusterValue(8)]
        @test stderror(mc) != stderror(m)
        out = text(modelsummary(of, mc; print_clusters = true,
            regression_statistics = [Nobs, VcovType]))
        @test occursin("Cluster 1", out)
        @test !occursin("Cluster 1 Clustering", out)
        @test occursin("CR1", out)
    end

    # Absorbed fixed effects: `Fixed effect k`, without the fixed-effect suffix; the
    # within R² is not stored.
    ofe = Regress.ols(hcat(x1, x), y; fe = (firm, year), coefnames = ["x1", "x"])
    ivfe = Regress.iv(Regress.TSLS(), hcat(x1, z), hcat(x1, x), y; fe = (firm, year),
        coefnames = ["x1", "x"])
    fe_rows = [MS.UnnamedFixedEffectCoefName(1) => MS.FixedEffectValue(true),
        MS.UnnamedFixedEffectCoefName(2) => MS.FixedEffectValue(true)]
    for m in (ofe, ivfe)
        @test MS.other_stats(m, :fe) == fe_rows
        @test MS.applies(R2Within, m)
        @test_throws "Regress does not store the within R² of a" R2Within(m)
        @test MS.default_regression_statistics(m) == [Nobs, R2]
    end
    off = Regress.ols(df, @formula(y ~ x1 + x + Regress.fe(firm) + Regress.fe(year)))
    @test coef(ofe) ≈ coef(off)
    for mime in (MIME"text/plain"(), MIME"text/html"(), MIME"text/latex"())
        out = sprint(show, mime, modelsummary(off, ofe; regression_statistics = [Nobs, R2]))
        @test occursin("Firm Fixed Effects", out)
        @test occursin("Fixed effect 1", out)
        @test occursin("Fixed effect 2", out)
        @test !occursin("Fixed effect 1 Fixed Effects", out)
    end
    @test text(modelsummary(ofe; print_fe_suffix = false)) |>
          s -> occursin("Fixed effect 2", s)
    @test_throws "within R² of a OLSMatrixEstimator" modelsummary(off, ofe)

    @test string(MS.UnnamedFixedEffectCoefName(2)) == "Fixed effect 2"
    @test MS.UnnamedFixedEffectCoefName(1) == MS.UnnamedFixedEffectCoefName(1)
    @test MS.UnnamedFixedEffectCoefName(1) != MS.UnnamedFixedEffectCoefName(2)
    @test MS.UnnamedFixedEffectCoefName(1) !=
          MS.FixedEffectCoefName(MS.CoefName("Fixed effect 1"))
    @test replace(MS.UnnamedFixedEffectCoefName(1), "Fixed" => "Absorbed") ==
          MS.UnnamedFixedEffectCoefName(1)
end
