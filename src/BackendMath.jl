"""
    BackendMath(; latex[, typst, html, text])

A cell value that renders as raw backend-specific markup in SummaryTables.jl.

Only `latex` is required. The other backends are derived from it:
- `typst`: native Typst markup. Text outside `\$...\$` is escaped; math is translated for
  Greek letters, sub/superscripts, primes, accents, `\\frac`, `\\sqrt`, font commands,
  `\\text`, `\\operatorname`, spacing, and common symbols and operators. Any other LaTeX
  command throws an `ArgumentError`; pass `typst` explicitly in that case.
- `html` / `text`: converted from `latex` for Greek letters, sub/superscripts,
  and accents. Anything not recognized is passed through verbatim.

You can override any field explicitly.

# Examples
```julia
BackendMath(latex = raw"Sepal width (\$\\beta_1\$)")
# → typst: Sepal width (\$beta_1\$)
# → html:  Sepal width (<i>&beta;<sub>1</sub></i>)
# → text:  Sepal width (β₁)

BackendMath(latex = raw"\$R^2\$")
# → typst: \$R^2\$
# → html:  <i>R<sup>2</sup></i>
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
        html::String = _latex_to_html(latex),
        text::String = _latex_to_text(latex))
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
Base.showable(::MIME"text/html", ::BackendMath) = true
Base.showable(::MIME"text", ::BackendMath) = true

Base.show(io::IO, ::MIME"text/latex", m::BackendMath) = print(io, m.latex)
Base.show(io::IO, ::MIME"text/typst", m::BackendMath) = print(io, m.typst)
Base.show(io::IO, ::MIME"text/html", m::BackendMath) = print(io, m.html)
Base.show(io::IO, ::MIME"text", m::BackendMath) = print(io, m.text)
Base.show(io::IO, m::BackendMath) = print(io, m.text)

# ── LaTeX → Unicode (text) conversion ─────────────────────────────────────────

const _GREEK_UNICODE = Dict{String, String}(
    "alpha" => "α", "beta" => "β", "gamma" => "γ", "delta" => "δ",
    "epsilon" => "ε", "zeta" => "ζ", "eta" => "η", "theta" => "θ",
    "iota" => "ι", "kappa" => "κ", "lambda" => "λ", "mu" => "μ",
    "nu" => "ν", "xi" => "ξ", "pi" => "π", "rho" => "ρ",
    "sigma" => "σ", "tau" => "τ", "upsilon" => "υ", "phi" => "φ",
    "chi" => "χ", "psi" => "ψ", "omega" => "ω",
    "Gamma" => "Γ", "Delta" => "Δ", "Theta" => "Θ", "Lambda" => "Λ",
    "Xi" => "Ξ", "Pi" => "Π", "Sigma" => "Σ", "Upsilon" => "Υ",
    "Phi" => "Φ", "Psi" => "Ψ", "Omega" => "Ω"
)

const _SUPERSCRIPT_UNICODE = Dict{Char, Char}(
    '0' => '⁰', '1' => '¹', '2' => '²', '3' => '³', '4' => '⁴',
    '5' => '⁵', '6' => '⁶', '7' => '⁷', '8' => '⁸', '9' => '⁹',
    '+' => '⁺', '-' => '⁻', '=' => '⁼', '(' => '⁽', ')' => '⁾',
    'n' => 'ⁿ', 'i' => 'ⁱ'
)

const _SUBSCRIPT_UNICODE = Dict{Char, Char}(
    '0' => '₀', '1' => '₁', '2' => '₂', '3' => '₃', '4' => '₄',
    '5' => '₅', '6' => '₆', '7' => '₇', '8' => '₈', '9' => '₉',
    '+' => '₊', '-' => '₋', '=' => '₌', '(' => '₍', ')' => '₎',
    'a' => 'ₐ', 'e' => 'ₑ', 'i' => 'ᵢ', 'j' => 'ⱼ', 'o' => 'ₒ',
    'r' => 'ᵣ', 'u' => 'ᵤ', 'v' => 'ᵥ', 'x' => 'ₓ'
)

"""Convert a short sub/superscript body to Unicode. Returns `nothing` if any char is unmapped."""
function _to_unicode_script(s::AbstractString, table::Dict{Char, Char})
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
            cmd = String(chars[(i + 1):(j - 1)])
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
                    depth = 1
                    i += 1
                    start = i
                    while i <= n && depth > 0
                        chars[i] == '{' && (depth += 1)
                        chars[i] == '}' && (depth -= 1)
                        depth > 0 && (i += 1)
                    end
                    body = _latex_to_text(String(chars[start:(i - 1)]))
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
                depth = 1
                i += 1
                start = i
                while i <= n && depth > 0
                    chars[i] == '{' && (depth += 1)
                    chars[i] == '}' && (depth -= 1)
                    depth > 0 && (i += 1)
                end
                body = String(chars[start:(i - 1)])
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

const _GREEK_HTML = Dict{String, String}(
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
            cmd = String(chars[(i + 1):(j - 1)])
            if haskey(_GREEK_HTML, cmd)
                write(out, _GREEK_HTML[cmd])
                i = j
                i <= n && chars[i] == ' ' && (i += 1)
            elseif cmd == "hat" || cmd == "tilde" || cmd == "bar"
                accent = cmd == "hat" ? "\u0302" : cmd == "tilde" ? "\u0303" : "\u0304"
                i = j
                if i <= n && chars[i] == '{'
                    depth = 1
                    i += 1
                    start = i
                    while i <= n && depth > 0
                        chars[i] == '{' && (depth += 1)
                        chars[i] == '}' && (depth -= 1)
                        depth > 0 && (i += 1)
                    end
                    body = _latex_to_html(String(chars[start:(i - 1)]))
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
                depth = 1
                i += 1
                start = i
                while i <= n && depth > 0
                    chars[i] == '{' && (depth += 1)
                    chars[i] == '}' && (depth -= 1)
                    depth > 0 && (i += 1)
                end
                body = _latex_to_html(String(chars[start:(i - 1)]))
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

# Typst names of LaTeX math commands that take no argument. LaTeX's `\epsilon` and `\phi`
# are the lunate and loop forms (ϵ, ϕ), which Typst calls `epsilon.alt` and `phi.alt`.
const _TYPST_MATH_SYMBOLS = Dict{String, String}(
    "alpha" => "alpha", "beta" => "beta", "gamma" => "gamma", "delta" => "delta",
    "epsilon" => "epsilon.alt", "varepsilon" => "epsilon", "zeta" => "zeta",
    "eta" => "eta", "theta" => "theta", "vartheta" => "theta.alt", "iota" => "iota",
    "kappa" => "kappa", "lambda" => "lambda", "mu" => "mu", "nu" => "nu", "xi" => "xi",
    "pi" => "pi", "varpi" => "pi.alt", "rho" => "rho", "varrho" => "rho.alt",
    "sigma" => "sigma", "varsigma" => "sigma.alt", "tau" => "tau",
    "upsilon" => "upsilon", "phi" => "phi.alt", "varphi" => "phi", "chi" => "chi",
    "psi" => "psi", "omega" => "omega",
    "Gamma" => "Gamma", "Delta" => "Delta", "Theta" => "Theta", "Lambda" => "Lambda",
    "Xi" => "Xi", "Pi" => "Pi", "Sigma" => "Sigma", "Upsilon" => "Upsilon",
    "Phi" => "Phi", "Psi" => "Psi", "Omega" => "Omega",
    "times" => "times", "cdot" => "dot.op", "ast" => "ast.op", "pm" => "plus.minus",
    "mp" => "minus.plus", "le" => "<=", "leq" => "<=", "ge" => ">=", "geq" => ">=",
    "ne" => "!=", "neq" => "!=", "approx" => "approx", "sim" => "tilde.op",
    "equiv" => "equiv", "propto" => "prop", "in" => "in", "notin" => "in.not",
    "perp" => "perp", "mid" => "divides", "to" => "arrow.r", "rightarrow" => "arrow.r",
    "leftarrow" => "arrow.l", "Rightarrow" => "arrow.r.double",
    "infty" => "infinity", "partial" => "partial", "nabla" => "nabla",
    "ldots" => "dots.h", "dots" => "dots.h", "cdots" => "dots.c", "prime" => "prime",
    "checkmark" => "checkmark", "sum" => "sum", "prod" => "product", "int" => "integral",
    "log" => "log", "ln" => "ln", "exp" => "exp", "max" => "max", "min" => "min",
    "sup" => "sup", "inf" => "inf", "lim" => "lim", "det" => "det", "Pr" => "Pr",
    "arg" => "arg", "sin" => "sin", "cos" => "cos", "tan" => "tan",
    "quad" => "quad", "qquad" => "wide"
)

# LaTeX math commands with one argument and the Typst function that takes it.
const _TYPST_MATH_FUNCTIONS = Dict{String, String}(
    "hat" => "hat", "widehat" => "hat", "tilde" => "tilde", "widetilde" => "tilde",
    "bar" => "macron", "overline" => "overline", "underline" => "underline",
    "dot" => "dot", "ddot" => "dot.double", "vec" => "arrow", "check" => "caron",
    "breve" => "breve", "mathbf" => "bold", "boldsymbol" => "bold", "mathbb" => "bb",
    "mathcal" => "cal", "mathit" => "italic", "mathrm" => "upright"
)

# LaTeX commands whose argument is text, shown upright as a Typst string.
const _TYPST_MATH_TEXT = ("text", "textrm", "textnormal", "mbox")

# A backslash followed by a non-letter, in math.
const _TYPST_MATH_ESCAPES = Dict{Char, String}(
    ',' => "thin", ':' => "med", '>' => "med", ';' => "thick", ' ' => "space",
    '%' => "%", '_' => "\\_", '&' => "\\&", '#' => "\\#", '$' => "\\\$",
    '{' => "\\{", '}' => "\\}"
)

# A backslash followed by a non-letter, in text: the character itself.
const _LATEX_TEXT_ESCAPES = ('_', '%', '&', '#', '$', '{', '}', ' ')

# Characters with a meaning in Typst markup, escaped with a backslash in text.
const _TYPST_MARKUP_SPECIAL = ('*', '@', '<', '>', '[', ']', '`', '=', '+', '/', '"')

# Characters that are not valid unescaped in LaTeX text.
const _LATEX_TEXT_INVALID = ('_', '^', '&', '#', '%')

function _typst_unsupported(src, what)
    throw(ArgumentError("cannot convert $what in the LaTeX string $(repr(src)) to Typst; " *
                        "give the Typst markup explicitly with BackendMath(; latex, typst)"))
end

"""
    _latex_to_typst(s) -> String

Convert a LaTeX string to Typst markup. Text outside `\$...\$` is escaped so Typst shows it
literally (`--` and `---` become en and em dashes, the LaTeX escapes `\\_`, `\\%`, `\\&`, `\\#`,
`\\\$`, `\\{`, `\\}` become the character). Math becomes native Typst math: Greek letters,
`^`/`_` scripts, primes, accents (`\\hat`, `\\bar`, `\\tilde`, ...), `\\frac`, `\\sqrt`, font
commands (`\\mathbf`, `\\mathbb`, `\\mathrm`, ...), `\\text`, `\\operatorname`, spacing commands,
and the symbols and operators in `_TYPST_MATH_SYMBOLS`. Adjacent letters are separate symbols, as
in LaTeX (`\$xy\$` → `\$x y\$`).

Throws an `ArgumentError` for any other command, an unmatched `\$` or brace, or a character that
is not valid unescaped LaTeX (`_`, `^`, `&`, `#`, `%` in text; `&`, `#`, `%` in math).
"""
function _latex_to_typst(s::AbstractString)
    src = String(s)
    chars = collect(src)
    n = length(chars)
    out = IOBuffer()
    i = 1
    while i <= n
        c = chars[i]
        if c == '$'
            j = _closing_dollar(chars, i + 1, src)
            p = _MathScan(chars, i + 1, j - 1, src)
            print(out, '$', _typst_join(_tm_seq!(p, false, nothing)), '$')
            i = j + 1
        elseif c == '\\'
            i == n && _typst_unsupported(src, "a trailing backslash")
            e = chars[i + 1]
            e in _LATEX_TEXT_ESCAPES ||
                _typst_unsupported(src, "\"\\$(_command_at(chars, i + 1))\"")
            _write_typst_text(out, e)
            i += 2
        elseif c == '{' || c == '}'
            i += 1
        elseif c == '-'
            k = i
            while k <= n && chars[k] == '-'
                k += 1
            end
            run = k - i
            print(out, run == 1 ? "\\-" : run == 2 ? "–" : run == 3 ? "—" : "\\-"^run)
            i = k
        elseif c in _LATEX_TEXT_INVALID
            _typst_unsupported(src, "an unescaped \"$c\" outside math")
        else
            _write_typst_text(out, c)
            i += 1
        end
    end
    return String(take!(out))
end

function _write_typst_text(out, c)
    c in _TYPST_MARKUP_SPECIAL || c in ('\\', '_', '#', '$', '-') ?
    print(out, '\\', c) : print(out, c)
end

function _command_at(chars, k)
    isletter(chars[k]) || return string(chars[k])
    j = k
    while j <= length(chars) && isletter(chars[j])
        j += 1
    end
    return String(chars[k:(j - 1)])
end

function _closing_dollar(chars, k, src)
    while k <= length(chars)
        chars[k] == '\\' && (k += 2; continue)
        chars[k] == '$' && return k
        k += 1
    end
    _typst_unsupported(src, "an unmatched \"\$\"")
end

mutable struct _MathScan
    const chars::Vector{Char}
    i::Int
    const stop::Int
    const src::String
end

_typst_join(tokens) = join(tokens, ' ')

# Parse math up to `close` (a `Char`, consumed) or the end of the span (`close === nothing`).
# Inside a function argument or a script body (`grouped`), commas and semicolons are escaped so
# Typst does not split the argument, and so are parentheses and brackets when unbalanced.
function _tm_seq!(p::_MathScan, grouped::Bool, close)
    toks = String[]
    while p.i <= p.stop
        c = p.chars[p.i]
        if c == close
            p.i += 1
            return grouped ? _escape_unbalanced(toks) : toks
        elseif isspace(c)
            p.i += 1
        elseif c == '}'
            _typst_unsupported(p.src, "an unmatched \"}\"")
        elseif c == '^' || c == '_'
            p.i += 1
            body = _tm_arg!(p)
            base = isempty(toks) ? "\"\"" : pop!(toks)
            push!(toks, base * c * _script_body(body))
        elseif c == '\''
            p.i += 1
            base = isempty(toks) ? "\"\"" : pop!(toks)
            push!(toks, base * "'")
        elseif c == '{'
            p.i += 1
            append!(toks, _tm_seq!(p, grouped, '}'))
        elseif isdigit(c)
            push!(toks, _tm_number!(p))
        else
            push!(toks, _tm_atom!(p, grouped))
        end
    end
    close === nothing ||
        _typst_unsupported(p.src, "an unmatched \"$(close == '}' ? '{' : '[')\"")
    return grouped ? _escape_unbalanced(toks) : toks
end

function _escape_unbalanced(toks)
    balanced = count(==("("), toks) == count(==(")"), toks) &&
               count(==("["), toks) == count(==("]"), toks)
    balanced && return toks
    return [t in ("(", ")", "[", "]") ? "\\" * t : t for t in toks]
end

# A script body needs parentheses unless it is a single name or number.
function _script_body(body)
    length(body) == 1 && occursin(r"^[\p{L}\d.]+$", body[1]) ? body[1] :
    "(" * _typst_join(body) * ")"
end

function _tm_number!(p::_MathScan)
    k = p.i
    while k <= p.stop && (isdigit(p.chars[k]) ||
           (p.chars[k] == '.' && k < p.stop && isdigit(p.chars[k + 1])))
        k += 1
    end
    tok = String(p.chars[p.i:(k - 1)])
    p.i = k
    return tok
end

# One argument of a command or script: a braced group, or a single letter, digit, or command.
function _tm_arg!(p::_MathScan)
    while p.i <= p.stop && isspace(p.chars[p.i])
        p.i += 1
    end
    (p.i > p.stop || p.chars[p.i] in ('}', '^', '_')) &&
        _typst_unsupported(p.src, "a command or script without an argument")
    c = p.chars[p.i]
    if c == '{'
        p.i += 1
        return _tm_seq!(p, true, '}')
    elseif isdigit(c)
        p.i += 1
        return [string(c)]
    else
        return [_tm_atom!(p, true)]
    end
end

function _tm_atom!(p::_MathScan, grouped::Bool)
    c = p.chars[p.i]
    p.i += 1
    c == '\\' && return _tm_command!(p)
    isletter(c) && return string(c)
    c in ('&', '#', '%') && _typst_unsupported(p.src, "an unescaped \"$c\" in math")
    c == '~' && return "space.nobreak"
    c in ('/', '"', '@', '`') && return "\\" * c
    grouped && c in (',', ';') && return "\\" * c
    return string(c)
end

function _tm_command!(p::_MathScan)
    p.i > p.stop && _typst_unsupported(p.src, "a trailing backslash")
    c = p.chars[p.i]
    if !isletter(c)
        p.i += 1
        haskey(_TYPST_MATH_ESCAPES, c) && return _TYPST_MATH_ESCAPES[c]
        _typst_unsupported(p.src, "\"\\$c\"")
    end
    name = _command_at(p.chars, p.i)
    p.i += length(name)
    haskey(_TYPST_MATH_SYMBOLS, name) && return _TYPST_MATH_SYMBOLS[name]
    if haskey(_TYPST_MATH_FUNCTIONS, name)
        return _TYPST_MATH_FUNCTIONS[name] * "(" * _typst_join(_tm_arg!(p)) * ")"
    elseif name == "frac"
        num = _typst_join(_tm_arg!(p))
        return "frac(" * num * ", " * _typst_join(_tm_arg!(p)) * ")"
    elseif name == "sqrt"
        while p.i <= p.stop && isspace(p.chars[p.i])
            p.i += 1
        end
        if p.i <= p.stop && p.chars[p.i] == '['
            p.i += 1
            index = _typst_join(_tm_seq!(p, true, ']'))
            return "root(" * index * ", " * _typst_join(_tm_arg!(p)) * ")"
        end
        return "sqrt(" * _typst_join(_tm_arg!(p)) * ")"
    elseif name in _TYPST_MATH_TEXT
        return _typst_string(_tm_text_arg!(p))
    elseif name == "operatorname"
        return "op(" * _typst_string(_tm_text_arg!(p)) * ")"
    end
    _typst_unsupported(p.src, "\"\\$name\"")
end

_typst_string(s) = "\"" * replace(s, '\\' => "\\\\", '"' => "\\\"") * "\""

# The braced text argument of `\text` and similar commands, with LaTeX text escapes resolved.
function _tm_text_arg!(p::_MathScan)
    while p.i <= p.stop && isspace(p.chars[p.i])
        p.i += 1
    end
    (p.i <= p.stop && p.chars[p.i] == '{') ||
        _typst_unsupported(p.src, "a text command without a braced argument")
    p.i += 1
    out = IOBuffer()
    depth = 1
    while p.i <= p.stop
        c = p.chars[p.i]
        if c == '\\'
            p.i == p.stop && _typst_unsupported(p.src, "a trailing backslash")
            e = p.chars[p.i + 1]
            e in _LATEX_TEXT_ESCAPES ||
                _typst_unsupported(p.src, "\"\\$(_command_at(p.chars, p.i + 1))\" in text")
            print(out, e)
            p.i += 2
            continue
        elseif c == '{'
            depth += 1
        elseif c == '}'
            depth -= 1
            depth == 0 && (p.i += 1; return String(take!(out)))
        elseif c == '~'
            print(out, '\u00a0')
        elseif c in _LATEX_TEXT_INVALID
            _typst_unsupported(p.src, "an unescaped \"$c\" in text")
        else
            print(out, c)
        end
        p.i += 1
    end
    _typst_unsupported(p.src, "an unmatched \"{\"")
end

# ── Checkmark constant ────────────────────────────────────────────────────────

"""
    Checkmark

A backend-adaptive checkmark symbol. Use as `yes_indicator = Checkmark` in `modelsummary`.
"""
const Checkmark = BackendMath(
    latex = raw"$\checkmark$",
    typst = "✓",
    html = "&#x2713;",
    text = "✓"
)

# ── R² helper ────────────────────────────────────────────────────────────────

"""
    _r2label(prefix::String) -> BackendMath

Build a backend-adaptive R² label with the given prefix (e.g. `"Adjusted "`).
"""
function _r2label(prefix::String)
    BackendMath(latex = prefix * raw"$R^2$")
end
