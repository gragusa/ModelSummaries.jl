using Test
using ExplicitImports
using ModelSummaries
# Loading the trigger packages loads the extensions, which ExplicitImports then checks as
# submodules of ModelSummaries; the result does not depend on what earlier tests loaded.
# `import`, not `using`: FixedEffectModels and Regress both export `fe` and `reg`, and the
# test files share `Main`.
import GLM, FixedEffectModels, Regress, CovarianceMatrices

const EXTENSIONS = (:ModelSummariesGLMExt, :ModelSummariesFixedEffectModelsExt,
    :ModelSummariesRegressExt, :ModelSummariesCovarianceMatricesExt)

# Names used although their owners do not declare them `public`:
# - `Base.broadcastable` is the documented hook for scalar-like broadcasting, and
#   `Base.typename(D).wrapper` is the only way to strip a distribution's type parameters.
# - `SummaryTables.to_docx` and WriteDocx's `Document`, `Body`, `Section`, and `save` are the
#   DOCX path documented in SummaryTables' manual.
# - The extensions dispatch on model and response types that GLM (`AbstractGLM`,
#   `LinPredModel`, `LmResp`, `GlmResp`), StatsModels (`TableRegressionModel`),
#   FixedEffectModels (`FixedEffectTerm`, Vcov's `SimpleCovariance`, `RobustCovariance`,
#   `ClusterCovariance`), and CovarianceMatrices (`Fixed` bandwidth) do not declare public.
# - `Regress.has_fe` is Regress's fixed-effects predicate, not declared public.
const NONPUBLIC_QUALIFIED = (
    :broadcastable, :typename, :to_docx, :Document, :Body, :Section,
    :save, :AbstractGLM, :LinPredModel, :LmResp, :GlmResp, :TableRegressionModel,
    :FixedEffectTerm, :SimpleCovariance, :RobustCovariance, :ClusterCovariance, :Fixed)
const NONPUBLIC_EXPLICIT = (:has_fe,)

@testset "ExplicitImports" begin
    for ext in EXTENSIONS
        @test Base.get_extension(ModelSummaries, ext) isa Module
    end
    test_explicit_imports(ModelSummaries;
        all_qualified_accesses_are_public = (; ignore = NONPUBLIC_QUALIFIED),
        all_explicit_imports_are_public = (; ignore = NONPUBLIC_EXPLICIT))
    for ext in EXTENSIONS
        test_explicit_imports(Base.get_extension(ModelSummaries, ext);
            all_qualified_accesses_are_public = (; ignore = NONPUBLIC_QUALIFIED),
            all_explicit_imports_are_public = (; ignore = NONPUBLIC_EXPLICIT))
    end
end
