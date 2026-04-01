"""
    BackendMath(; latex[, typst, html, text])

A cell value that renders as raw backend-specific markup in SummaryTables.jl.

Only `latex` is required. The other backends are derived automatically:
- `typst`: defaults to `latex` (math syntax is identical for common cases).
- `html` / `text`: converted from `latex` for Greek letters, sub/superscripts,
  and common math symbols. Anything not recognized is passed through verbatim.

You can override any field explicitly.

# Examples
```julia
BackendMath(latex = raw"Sepal width (\$\\beta_1\$)")
# → typst: Sepal width (\$\\beta_1\$)
# → html:  Sepal width (<i>&beta;</i><sub>1</sub>)
# → text:  Sepal width (β₁)

BackendMath(latex = raw"\$R^2\$")
# → html:  <i>R</i><sup>2</sup>
# → text:  R²
```
"""
struct BackendMath
    latex::String
    typst::String
    html::String
    text::String
end

function BackendMath(; latex::String,
                       typst::String = _latex_to_typst(latex),
                       html::String  = _latex_to_html(latex),
                       text::String  = _latex_to_text(latex))
    BackendMath(latex, typst, html, text)
end

"""
    BackendMath(latex_string)

Positional convenience constructor. Treats the argument as a LaTeX string and
auto-derives the other backends.
"""
BackendMath(s::AbstractString) = BackendMath(; latex = String(s))

Base.broadcastable(x::BackendMath) = Ref(x)

Base.showable(::MIME"text/latex", ::BackendMath) = true
Base.showable(::MIME"text/typst", ::BackendMath) = true
Base.showable(::MIME"text/html",  ::BackendMath) = true
Base.showable(::MIME"text",       ::BackendMath) = true

Base.show(io::IO, ::MIME"text/latex", m::BackendMath) = print(io, m.latex)
Base.show(io::IO, ::MIME"text/typst", m::BackendMath) = print(io, m.typst)
Base.show(io::IO, ::MIME"text/html",  m::BackendMath) = print(io, m.html)
Base.show(io::IO, ::MIME"text",       m::BackendMath) = print(io, m.text)
Base.show(io::IO,                     m::BackendMath) = print(io, m.text)

# ── LaTeX → Unicode (text) conversion ─────────────────────────────────────────

const _GREEK_UNICODE = Dict{String,String}(
    "alpha"    => "α", "beta"     => "β", "gamma"    => "γ", "delta"    => "δ",
    "epsilon"  => "ε", "zeta"     => "ζ", "eta"      => "η", "theta"    => "θ",
    "iota"     => "ι", "kappa"    => "κ", "lambda"   => "λ", "mu"       => "μ",
    "nu"       => "ν", "xi"       => "ξ", "pi"       => "π", "rho"      => "ρ",
    "sigma"    => "σ", "tau"      => "τ", "upsilon"  => "υ", "phi"      => "φ",
    "chi"      => "χ", "psi"      => "ψ", "omega"    => "ω",
    "Gamma"    => "Γ", "Delta"    => "Δ", "Theta"    => "Θ", "Lambda"   => "Λ",
    "Xi"       => "Ξ", "Pi"       => "Π", "Sigma"    => "Σ", "Upsilon"  => "Υ",
    "Phi"      => "Φ", "Psi"      => "Ψ", "Omega"    => "Ω",
)

const _SUPERSCRIPT_UNICODE = Dict{Char,Char}(
    '0' => '⁰', '1' => '¹', '2' => '²', '3' => '³', '4' => '⁴',
    '5' => '⁵', '6' => '⁶', '7' => '⁷', '8' => '⁸', '9' => '⁹',
    '+' => '⁺', '-' => '⁻', '=' => '⁼', '(' => '⁽', ')' => '⁾',
    'n' => 'ⁿ', 'i' => 'ⁱ',
)

const _SUBSCRIPT_UNICODE = Dict{Char,Char}(
    '0' => '₀', '1' => '₁', '2' => '₂', '3' => '₃', '4' => '₄',
    '5' => '₅', '6' => '₆', '7' => '₇', '8' => '₈', '9' => '₉',
    '+' => '₊', '-' => '₋', '=' => '₌', '(' => '₍', ')' => '₎',
    'a' => 'ₐ', 'e' => 'ₑ', 'i' => 'ᵢ', 'j' => 'ⱼ', 'o' => 'ₒ',
    'r' => 'ᵣ', 'u' => 'ᵤ', 'v' => 'ᵥ', 'x' => 'ₓ',
)

"""Convert a short sub/superscript body to Unicode. Returns `nothing` if any char is unmapped."""
function _to_unicode_script(s::AbstractString, table::Dict{Char,Char})
    buf = IOBuffer()
    for c in s
        mapped = get(table, c, nothing)
        mapped === nothing && return nothing
        write(buf, mapped)
    end
    String(take!(buf))
end

"""
    _latex_to_text(s) -> String

Best-effort conversion of a LaTeX string to plain Unicode text.
Handles: `\$...\$` math delimiters, `^{...}` / `_{...}` scripts,
`\\greek` commands, and `\\hat`, `\\bar`, `\\tilde`.
"""
function _latex_to_text(s::AbstractString)
    out = IOBuffer()
    i = 1
    chars = collect(s)
    n = length(chars)
    while i <= n
        c = chars[i]
        if c == '$'
            # Strip math delimiters — process contents inline
            i += 1
        elseif c == '\\' && i < n
            # Try to read a command name
            j = i + 1
            while j <= n && isletter(chars[j])
                j += 1
            end
            cmd = String(chars[i+1:j-1])
            if haskey(_GREEK_UNICODE, cmd)
                write(out, _GREEK_UNICODE[cmd])
                i = j
                # LaTeX eats whitespace after command names
                i <= n && chars[i] == ' ' && (i += 1)
            elseif cmd == "hat" || cmd == "tilde" || cmd == "bar"
                accent = cmd == "hat" ? '\u0302' : cmd == "tilde" ? '\u0303' : '\u0304'
                # consume the argument: \hat{x} or \hat x
                i = j
                if i <= n && chars[i] == '{'
                    # find closing brace
                    depth = 1; i += 1; start = i
                    while i <= n && depth > 0
                        chars[i] == '{' && (depth += 1)
                        chars[i] == '}' && (depth -= 1)
                        depth > 0 && (i += 1)
                    end
                    body = _latex_to_text(String(chars[start:i-1]))
                    i += 1  # skip '}'
                elseif i <= n
                    body = string(chars[i])
                    i += 1
                else
                    body = ""
                end
                write(out, body)
                write(out, accent)
            else
                # Unknown command — pass through without backslash
                write(out, cmd)
                i = j
            end
        elseif (c == '^' || c == '_') && i < n
            table = c == '^' ? _SUPERSCRIPT_UNICODE : _SUBSCRIPT_UNICODE
            i += 1
            if chars[i] == '{'
                depth = 1; i += 1; start = i
                while i <= n && depth > 0
                    chars[i] == '{' && (depth += 1)
                    chars[i] == '}' && (depth -= 1)
                    depth > 0 && (i += 1)
                end
                body = String(chars[start:i-1])
                i += 1  # skip '}'
            else
                body = string(chars[i])
                i += 1
            end
            uni = _to_unicode_script(body, table)
            if uni !== nothing
                write(out, uni)
            else
                # Fallback: just write the body
                write(out, body)
            end
        elseif c == '{' || c == '}'
            # Strip bare braces (grouping)
            i += 1
        else
            write(out, c)
            i += 1
        end
    end
    String(take!(out))
end

# ── LaTeX → HTML conversion ──────────────────────────────────────────────────

const _GREEK_HTML = Dict{String,String}(
    k => "&$k;" for k in keys(_GREEK_UNICODE)
)
# HTML entities use the same names as LaTeX for Greek letters

"""
    _latex_to_html(s) -> String

Best-effort conversion of a LaTeX string to HTML.
Math-mode content (`\$...\$`) is rendered in italic.
`^{...}` → `<sup>...</sup>`, `_{...}` → `<sub>...</sub>`,
`\\greek` → `&entity;`.
"""
function _latex_to_html(s::AbstractString)
    out = IOBuffer()
    i = 1
    chars = collect(s)
    n = length(chars)
    in_math = false
    while i <= n
        c = chars[i]
        if c == '$'
            in_math = !in_math
            if in_math
                write(out, "<i>")
            else
                write(out, "</i>")
            end
            i += 1
        elseif c == '\\' && i < n
            j = i + 1
            while j <= n && isletter(chars[j])
                j += 1
            end
            cmd = String(chars[i+1:j-1])
            if haskey(_GREEK_HTML, cmd)
                write(out, _GREEK_HTML[cmd])
                i = j
                i <= n && chars[i] == ' ' && (i += 1)
            elseif cmd == "hat" || cmd == "tilde" || cmd == "bar"
                accent = cmd == "hat" ? "\u0302" : cmd == "tilde" ? "\u0303" : "\u0304"
                i = j
                if i <= n && chars[i] == '{'
                    depth = 1; i += 1; start = i
                    while i <= n && depth > 0
                        chars[i] == '{' && (depth += 1)
                        chars[i] == '}' && (depth -= 1)
                        depth > 0 && (i += 1)
                    end
                    body = _latex_to_html(String(chars[start:i-1]))
                    i += 1
                elseif i <= n
                    body = string(chars[i])
                    i += 1
                else
                    body = ""
                end
                write(out, body)
                write(out, accent)
            else
                write(out, cmd)
                i = j
            end
        elseif (c == '^' || c == '_') && i < n
            tag = c == '^' ? "sup" : "sub"
            i += 1
            if chars[i] == '{'
                depth = 1; i += 1; start = i
                while i <= n && depth > 0
                    chars[i] == '{' && (depth += 1)
                    chars[i] == '}' && (depth -= 1)
                    depth > 0 && (i += 1)
                end
                body = _latex_to_html(String(chars[start:i-1]))
                i += 1
            else
                body = string(chars[i])
                i += 1
            end
            write(out, "<$tag>", body, "</$tag>")
        elseif c == '{' || c == '}'
            i += 1
        elseif c == '&'
            write(out, "&amp;")
            i += 1
        elseif c == '<'
            write(out, "&lt;")
            i += 1
        elseif c == '>'
            write(out, "&gt;")
            i += 1
        else
            write(out, c)
            i += 1
        end
    end
    String(take!(out))
end

# ── LaTeX → Typst conversion ──────────────────────────────────────────────────

"""
    _latex_to_typst(s) -> String

Convert a LaTeX string to Typst. Text outside `\$...\$` is passed through
verbatim. Math sections (`\$...\$`) are wrapped in `#mi("...")` so that
MiTeX (used by Quarto and other Typst toolchains) renders the LaTeX math.
"""
function _latex_to_typst(s::AbstractString)
    out = IOBuffer()
    i = 1
    chars = collect(s)
    n = length(chars)
    while i <= n
        if chars[i] == '$'
            # Find the closing $
            j = findnext(==('$'), chars, i + 1)
            if j !== nothing
                math = String(chars[i+1:j-1])
                write(out, "#mi(\"\$")
                write(out, math)
                write(out, "\$\")")
                i = j + 1
            else
                # No closing $ — pass through
                write(out, chars[i])
                i += 1
            end
        else
            write(out, chars[i])
            i += 1
        end
    end
    String(take!(out))
end

# ── Checkmark constant ────────────────────────────────────────────────────────

"""
    Checkmark

A backend-adaptive checkmark symbol. Use as `yes_indicator = Checkmark` in `modelsummary`.
"""
const Checkmark = BackendMath(
    latex = raw"$\checkmark$",
    typst = "✓",
    html  = "&#x2713;",
    text  = "✓",
)

# ── R² helper ────────────────────────────────────────────────────────────────

"""
    _r2label(prefix::String) -> BackendMath

Build a backend-adaptive R² label with the given prefix (e.g. `"Adjusted "`).
"""
function _r2label(prefix::String)
    BackendMath(latex = prefix * raw"$R^2$")
end
