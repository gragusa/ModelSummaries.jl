using ModelSummaries
using Test
using GLM, DataFrames

const MS = ModelSummaries
const to_typst = MS._latex_to_typst

@testset "LaTeX to Typst: math" begin
    @test to_typst(raw"$R^2$") == raw"$R^2$"
    @test to_typst(raw"Adjusted $R^2$") == raw"Adjusted $R^2$"
    @test to_typst(raw"Sepal width ($\beta_1$)") == raw"Sepal width ($beta_1$)"
    # Adjacent letters are separate symbols, as in LaTeX; Typst would read `it` as one name.
    @test to_typst(raw"$x_{it}$") == raw"$x_(i t)$"
    @test to_typst(raw"$xy$") == raw"$x y$"
    # A LaTeX script without braces takes one character.
    @test to_typst(raw"$x_12$") == raw"$x_1 2$"
    @test to_typst(raw"$x^{12}$") == raw"$x^12$"
    @test to_typst(raw"$x^{-1}$") == raw"$x^(- 1)$"
    @test to_typst(raw"$^2$") == raw"$\"\"^2$"
    @test to_typst(raw"$f'(x)$") == raw"$f' ( x )$"
    @test to_typst(raw"$\hat{\beta}_1$") == raw"$hat(beta)_1$"
    @test to_typst(raw"$\hat\beta$") == raw"$hat(beta)$"
    @test to_typst(raw"$\bar{x}$") == raw"$macron(x)$"
    @test to_typst(raw"$\tilde{y}$") == raw"$tilde(y)$"
    @test to_typst(raw"$\hat{\sigma}^2$") == raw"$hat(sigma)^2$"
    # LaTeX's \epsilon and \phi are the lunate and loop forms.
    @test to_typst(raw"$\epsilon \varepsilon \phi \varphi$") ==
          raw"$epsilon.alt epsilon phi.alt phi$"
    @test to_typst(raw"$a \times b$") == raw"$a times b$"
    @test to_typst(raw"$\checkmark$") == raw"$checkmark$"
    @test to_typst(raw"$a \leq b$") == raw"$a <= b$"
    # Spaces keep LaTeX's `<=` two characters, not Typst's ≤ shorthand.
    @test to_typst(raw"$a<=b$") == raw"$a < = b$"
    @test to_typst(raw"$a/b$") == raw"$a \/ b$"
    @test to_typst(raw"$\frac{a,b}{c}$") == raw"$frac(a \, b, c)$"
    @test to_typst(raw"$\sqrt{x}$") == raw"$sqrt(x)$"
    @test to_typst(raw"$\sqrt[n]{x}$") == raw"$root(n, x)$"
    @test to_typst(raw"$\hat{f(x)}$") == raw"$hat(f ( x ))$"
    @test to_typst(raw"$\hat{(}$") == raw"$hat(\()$"
    @test to_typst(raw"$\text{OLS}_{\text{a\_b}}$") == raw"$\"OLS\"_(\"a_b\")$"
    @test to_typst(raw"$\operatorname{Var}(x)$") == raw"$op(\"Var\") ( x )$"
    @test to_typst(raw"$\mathbb{E}[y \mid x]$") == raw"$bb(E) [ y divides x ]$"
    @test to_typst(raw"$a\,b$") == raw"$a thin b$"
    @test to_typst(raw"$5\%$") == raw"$5 %$"
    @test to_typst(raw"$1.5x$") == raw"$1.5 x$"
end

@testset "LaTeX to Typst: text" begin
    @test to_typst("Cox-Snell ") == "Cox\\-Snell "
    @test to_typst("a--b---c") == "a–b—c"
    @test to_typst(raw"x\_2 \& <z> 5\%") == raw"x\_2 & \<z\> 5%"
    @test to_typst(raw"\# \$ \{\}") == raw"\# \$ {}"
    @test to_typst("= h") == "\\= h"
    @test to_typst("+ a // b") == "\\+ a \\/\\/ b"
    @test to_typst("*a* @r [b] `c` \"q\"") == "\\*a\\* \\@r \\[b\\] \\`c\\` \\\"q\\\""
    @test to_typst("{grouped} a~b") == "grouped a~b"
end

@testset "LaTeX to Typst: unsupported input throws" begin
    hint = "give the Typst markup explicitly with BackendMath(; latex, typst)"
    @test_throws hint to_typst(raw"$\left( x \right)$")
    @test_throws "\"\\left\"" to_typst(raw"$\left( x \right)$")
    @test_throws "\"\\textbf\"" to_typst(raw"\textbf{x}")
    @test_throws "\"\\\\\"" to_typst(raw"a \\ b")
    @test_throws "unmatched \"\$\"" to_typst(raw"$x")
    @test_throws "unmatched \"{\"" to_typst(raw"$x_{1$")
    @test_throws "unmatched \"}\"" to_typst(raw"$x}$")
    @test_throws "without an argument" to_typst(raw"$x^$")
    @test_throws "unescaped \"_\" outside math" to_typst("x_2")
    @test_throws "unescaped \"%\" outside math" to_typst("5%")
    @test_throws "unescaped \"&\" in math" to_typst(raw"$a & b$")
    @test_throws "\"\\textbf\" in text" to_typst(raw"$\text{\textbf{x}}$")
    # The Typst form is derived on construction, so the error surfaces there.
    @test_throws ArgumentError BackendMath(raw"$\left( x \right)$")
    @test BackendMath(latex = raw"$\left( x \right)$", typst = raw"$lr((x))$").typst ==
          raw"$lr((x))$"
end

@testset "BackendMath derives native Typst" begin
    @test BackendMath(raw"Sepal width ($\beta_1$)").typst == raw"Sepal width ($beta_1$)"
    @test sprint(show, MIME"text/typst"(), MS.label(R2)) == raw"$R^2$"
    @test sprint(show, MIME"text/typst"(), MS.label(AdjR2)) == raw"Adjusted $R^2$"
    df = DataFrame(y = sin.(1:30), x = cos.(1:30))
    typ = sprint(show, MIME"text/typst"(), modelsummary(lm(@formula(y ~ x), df)))
    @test occursin(raw"[$R^2$]", typ)
    @test !occursin("#mi(", typ)
end

@testset "Statistic labels given with the statistic" begin
    df = DataFrame(y = sin.(1:30), x = cos.(1:30))
    pval = BackendMath(latex = raw"\textit{p-val}", typst = "_p-val_",
        html = "<i>p-val</i>", text = "p-val")
    t = modelsummary(lm(@formula(y ~ x), df);
        regression_statistics = [Nobs, R2 => "R-squared", AdjR2 => pval])
    typ = sprint(show, MIME"text/typst"(), t)
    @test occursin("[_p-val_]", typ)
    @test occursin("R-squared", typ)
    @test occursin(raw"\textit{p-val}", sprint(show, MIME"text/latex"(), t))
    @test occursin("<i>p-val</i>", sprint(show, MIME"text/html"(), t))
    @test occursin("p-val", sprint(show, MIME"text/plain"(), t))
end

const TYPST = Sys.which("typst")

# Compile `src` with the typst CLI; return `nothing` on success and the diagnostics otherwise.
function typst_errors(src)
    mktempdir() do dir
        f = joinpath(dir, "t.typ")
        write(f, src)
        err = IOBuffer()
        ok = success(pipeline(`$TYPST compile $f $(joinpath(dir, "t.pdf"))`; stderr = err))
        return ok ? nothing : String(take!(err))
    end
end

function typst_cells(cells)
    "#table(columns: 1,\n" * join(("[" * c * "]" for c in cells), ",\n") * ")\n"
end

if TYPST === nothing
    @testset "Typst output compiles" begin
        @test_skip "typst not on PATH"
    end
else
    @testset "Typst output compiles" begin
        df = DataFrame(y = sin.(1:60), x1 = cos.(1:60), x2 = sin.(2 .* (1:60)),
            g = repeat(["a", "b_1", "c"], 20))
        mktempdir() do dir
            f = joinpath(dir, "default.typ")
            modelsummary(lm(@formula(y ~ x1 + x2), df); file = f)
            @test typst_errors(read(f, String)) === nothing

            labels = Dict("x1" => BackendMath(raw"$\beta_1$"), "x2" => "x_2 & <z>",
                "g" => BackendMath(raw"$\gamma$"))
            m = lm(@formula(y ~ x1 * x2 + g * x1), df)
            f = joinpath(dir, "parts.typ")
            modelsummary(m; labels, file = f, regression_statistics = [Nobs, R2, AdjR2])
            @test typst_errors(read(f, String)) === nothing
        end

        # Docstring and README examples, and every name in the conversion tables, so a
        # Typst release that renames a symbol fails here.
        examples = [raw"Sepal width ($\beta_1$)", raw"$R^2$", raw"$\hat{\sigma}^2$",
            raw"Cox-Snell $R^2$", raw"x\_2 \& <z> 5\% = + // @r [b]",
            raw"$\text{OLS}_{\text{a\_b}} \operatorname{Var}(x) \mathbb{E}[y \mid x]$",
            raw"$\frac{a,b}{c} \sqrt[n]{x} \hat{(} \,\:\;\ \%\_\&\#\$\{\} a~b$", raw"$^2$"]
        cells = [to_typst(s) for s in examples]
        append!(cells, to_typst("\$x \\$k y\$") for k in keys(MS._TYPST_MATH_SYMBOLS))
        append!(cells, to_typst("\$\\$k{xy}_1\$") for k in keys(MS._TYPST_MATH_FUNCTIONS))
        push!(cells, raw"$lr((sum_i x_i))^2$")  # README override example
        push!(cells, Checkmark.typst)
        @test typst_errors(typst_cells(cells)) === nothing
    end
end

@testset "Negative numbers are set with a minus sign" begin
    df = DataFrame(y = [1.0, 0.4, -0.3, -1.2, -2.1, -2.8], x = 1.0:6.0)
    t = modelsummary(lm(@formula(y ~ x), df))
    typ = sprint(show, MIME"text/typst"(), t)
    @test occursin("#\"−0.", typ)
    @test !occursin(r"\"-\d", typ)
    @test occursin(raw"$-$0.", sprint(show, MIME"text/latex"(), t))
    @test occursin("&minus;0.", sprint(show, MIME"text/html"(), t))
    @test occursin("-0.", sprint(show, MIME"text/plain"(), t))
    @test MS.with_minus("0.25") == "0.25"
    @test MS.with_minus("1e-08") == "1e-08"
    @test MS.with_minus("(-0.2, 3.1)").typst == "#\"(−0.2, 3.1)\""
end
