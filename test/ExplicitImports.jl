using Test
using ExplicitImports
using ModelSummaries

@testset "ExplicitImports" begin
    # `Base.broadcastable` is the documented hook for scalar-like broadcasting, and
    # `Base.typename(D).wrapper` is the only way to strip a distribution's type parameters.
    test_explicit_imports(ModelSummaries;
        all_qualified_accesses_are_public = (; ignore = (:broadcastable, :typename)))
end
