using Test
using ExplicitImports
using ModelSummaries

@testset "ExplicitImports" begin
    # `Base.broadcastable` is the documented hook for scalar-like broadcasting, and
    # `Base.typename(D).wrapper` is the only way to strip a distribution's type parameters.
    # `SummaryTables.to_docx` and WriteDocx's `Document`, `Body`, `Section`, and `save` are the
    # DOCX path documented in SummaryTables' manual; neither package declares them `public`.
    test_explicit_imports(ModelSummaries;
        all_qualified_accesses_are_public = (;
            ignore = (
            :broadcastable, :typename, :to_docx, :Document, :Body, :Section, :save)))
end
