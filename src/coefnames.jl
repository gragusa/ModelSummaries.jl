get_coefname(x::MatrixTerm) = mapreduce(get_coefname, vcat, x.terms)

"""
    abstract type AbstractCoefName end

These names largely mirror their equivalents in [StatsModels.jl](https://github.com/JuliaStats/StatsModels.jl).
The main difference here is that the names are always based on strings (instead of symbols). `string(x)` gives
the name as StatsModels prints it (the form `labels` keys match), [`ModelSummaries.display_name`](@ref) the form
shown in the table, and `replace(x, old => new)` applies a `transform_labels` replacement to every part of the name.

AbstractCoefName simply acts as a parent type to the other types. The other types are:
- [`CoefName`](@ref): for `Term`, `ContinuousTerm` and `FunctionTerm`
- [`InteractedCoefName`](@ref): for `InteractionTerm`
- [`CategoricalCoefName`](@ref): for `CategoricalTerm`
- [`InterceptCoefName`](@ref): for `ConstantTerm`

Using the function [`get_coefname`](@ref) will return the appropriate type for the term.
"""
abstract type AbstractCoefName end
(::Type{T})(x::T) where {T <: AbstractCoefName} = x
Base.broadcastable(x::AbstractCoefName) = Ref(x)

"""
    get_coefname(x::AbstractTerm)::CoefName
    get_coefname(x::Term)::CoefName
    get_coefname(x::InteractionTerm)::InteractedCoefName
    get_coefname(x::InterceptTerm{H})::InterceptCoefName
    get_coefname(x::CategoricalTerm)::CategoricalCoefName
"""
function get_coefname end

# for functionterm and continuousterm
#=
It might be nice to add a separate functionterm piece so that the internals could easily
change just like InteractedCoefName, but the internals are not parsed in the same way
which makes that extremely difficult to do
=#
"""
    struct CoefName <: AbstractCoefName
        name::String
    end

Used to store the name of a coefficient. This is used for `Term`, `ContinuousTerm` and `FunctionTerm`.
"""
struct CoefName <: AbstractCoefName
    name::String
    CoefName(name::AbstractString) = new(String(name))
end

value(x::CoefName) = x.name
Base.string(x::CoefName) = value(x)
get_coefname(x::AbstractTerm) = CoefName(coefnames(x))
get_coefname(x::Term) = CoefName(string(x.sym))
Base.replace(x::CoefName, r::Pair) = CoefName(replace(value(x), r))

get_coefname(x::AbstractString) = CoefName(String(x))
get_coefname(x::AbstractVector) = CoefName.(String.(x))

"""
    struct InteractedCoefName <: AbstractCoefName
        names::Vector
    end

Used to store the different coefficient names that makes up an InteractionTerm. The internals of the
vector are typically [`CoefName`](@ref), but can also be strings.

`string(x)` joins the parts with `" & "`, as StatsModels' `coefnames` does; this is the key a
`labels` dictionary must use (`labels = Dict("x & z" => "Treated × Post")`). Without such a key, `labels` keys for
the parts relabel each part (`labels = Dict("x" => "Treated")` shows `"Treated × z"`). The table shows the parts
joined by the `interaction_separator` keyword of [`modelsummary`](@ref) (default `" × "`). Two interactions are
equal when they have the same parts in any order.
"""
struct InteractedCoefName <: AbstractCoefName
    names::Vector
    InteractedCoefName(names::Vector) = new(names)
end

value(x::InteractedCoefName) = x.names
Base.string(x::InteractedCoefName) = join(string.(x.names), " & ")
Base.hash(x::InteractedCoefName, h::UInt) = hash(sort(string.(value(x))), h)
function Base.:(==)(x::InteractedCoefName, y::InteractedCoefName)
    sort(string.(value(x))) == sort(string.(value(y)))
end
function get_coefname(x::InteractionTerm)
    # One name per combination of the component terms' names, with the first
    # term varying fastest: the column order of `modelcols(::InteractionTerm, d)`.
    parts = (_along_dim(i, p) for (i, p) in enumerate(get_coefname.(x.terms)))
    out = broadcast((args...) -> InteractedCoefName(collect(args)), parts...)
    out isa AbstractArray ? vec(out) : out
end
_along_dim(i, a) = a
_along_dim(i, a::AbstractVector) = reshape(a, ntuple(Returns(1), i - 1)..., :)
function Base.replace(x::InteractedCoefName, r::Pair)
    InteractedCoefName(replace.(value(x), Ref(r)))
end

"""
    struct CategoricalCoefName <: AbstractCoefName
        name::String
        level::String
    end

Used to store the name of a coefficient for a `CategoricalTerm`. The `level` is the level of the categorical.
In other words, the `name` is the column name, the `level` is the category within that column.

Both `string(x)` and the table show `"name: level"`, which is also the form `labels` keys use
(`labels = Dict("species: setosa" => "Setosa")`). Without such a key, a `labels` key for `name` relabels the
variable name and keeps the level (`labels = Dict("species" => "Species")` shows `"Species: setosa"`).
"""
struct CategoricalCoefName <: AbstractCoefName
    name::String
    level::String
    function CategoricalCoefName(name::AbstractString, level::AbstractString)
        new(String(name), String(level))
    end
end

value(x::CategoricalCoefName) = x.name
Base.string(x::CategoricalCoefName) = "$(value(x)): $(x.level)"
function get_coefname(x::CategoricalTerm)
    [CategoricalCoefName(string(x.sym), string(n)) for n in x.contrasts.coefnames]
end

function Base.replace(x::CategoricalCoefName, r::Pair)
    CategoricalCoefName(
        replace(value(x), r),
        replace(x.level, r)
    )
end

"""
    struct InterceptCoefName <: AbstractCoefName end

Used as a simple indicator for the existence of an intercept term. It prints as `"(Intercept)"`, so
`labels = Dict("(Intercept)" => "Constant")` relabels the intercept of every model.
"""
struct InterceptCoefName <: AbstractCoefName end

Base.string(x::InterceptCoefName) = "(Intercept)"
get_coefname(x::InterceptTerm{H}) where {H} = H ? InterceptCoefName() : []
function Base.replace(x::InterceptCoefName, r::Pair)
    v = string(x)
    out = replace(v, r)
    if out == v
        InterceptCoefName()
    else
        out
    end
end

"""
    struct FixedEffectCoefName <: AbstractCoefName
        name::AbstractCoefName
    end

Used to store the name of a coefficient for a `FixedEffectTerm`.
The `name` is the name of the fixed effect. This allows a suffix to be
applied later.
"""
struct FixedEffectCoefName <: AbstractCoefName
    name::AbstractCoefName
    FixedEffectCoefName(x::AbstractCoefName) = new(x)
end

value(x::FixedEffectCoefName) = x.name
Base.string(x::FixedEffectCoefName) = string(x.name)
Base.:(==)(x::FixedEffectCoefName, y::FixedEffectCoefName) = x.name == y.name
Base.hash(x::FixedEffectCoefName, h::UInt) = hash(x.name, hash(FixedEffectCoefName, h))

Base.replace(x::FixedEffectCoefName, r::Pair) = FixedEffectCoefName(replace(x.name, r))

"""
    struct ClusterCoefName <: AbstractCoefName
        name::AbstractCoefName
    end

Used to store the name of a cluster variable, so that
[`ModelSummaries.cluster_suffix`](@ref) can be appended to it.
"""
struct ClusterCoefName <: AbstractCoefName
    name::AbstractCoefName
    ClusterCoefName(x::AbstractCoefName) = new(x)
end

ClusterCoefName(x::String) = ClusterCoefName(CoefName(x))

value(x::ClusterCoefName) = x.name
Base.string(x::ClusterCoefName) = string(x.name)
Base.:(==)(x::ClusterCoefName, y::ClusterCoefName) = x.name == y.name
Base.hash(x::ClusterCoefName, h::UInt) = hash(x.name, hash(ClusterCoefName, h))

Base.replace(x::ClusterCoefName, r::Pair) = ClusterCoefName(replace(x.name, r))

"""
    struct UnnamedClusterCoefName <: AbstractCoefName
        position::Int
    end

A clustering dimension given as data rather than as a column name. It is shown as
`Cluster k`, k being `position` (the dimension's place in the estimator), without
[`ModelSummaries.cluster_suffix`](@ref): the label already says it is a cluster.
`transform_labels` leaves it unchanged.
"""
struct UnnamedClusterCoefName <: AbstractCoefName
    position::Int
    UnnamedClusterCoefName(position::Integer) = new(position)
end

value(x::UnnamedClusterCoefName) = string(x)
Base.string(x::UnnamedClusterCoefName) = "Cluster $(x.position)"
Base.replace(x::UnnamedClusterCoefName, r::Pair) = x

"""
    struct FirstStageCoefName <: AbstractCoefName
        name::AbstractCoefName
    end

Used to store the name of a first-stage statistic for IV models.
"""
struct FirstStageCoefName <: AbstractCoefName
    name::AbstractCoefName
    FirstStageCoefName(x::AbstractCoefName) = new(x)
end

FirstStageCoefName(x::String) = FirstStageCoefName(CoefName(x))

value(x::FirstStageCoefName) = x.name
Base.string(x::FirstStageCoefName) = string(x.name)
Base.:(==)(x::FirstStageCoefName, y::FirstStageCoefName) = x.name == y.name
Base.hash(x::FirstStageCoefName, h::UInt) = hash(x.name, hash(FirstStageCoefName, h))

Base.replace(x::FirstStageCoefName, r::Pair) = FirstStageCoefName(replace(x.name, r))
