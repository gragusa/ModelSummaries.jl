using RDatasets
using ModelSummaries
using FixedEffectModels, GLM, Documenter, Aqua
using Test

##

#=
ambiguities is tested separately since it defaults to recursive=true
but there are packages that have ambiguities that will cause the test
to fail

piracies is disabled because vcov(spec) causes type piracy - this is
intentional and will be moved to CovarianceMatrices.jl in the future
=#
Aqua.test_ambiguities(ModelSummaries; recursive=false)
Aqua.test_all(ModelSummaries; ambiguities=false, piracies=false)

tests = [
        "default_changes.jl",
        "RegressionTables.jl",
        "decorations.jl",
        "label_transforms.jl",
        "table_format.jl",
        "new_features.jl",
        "MetricsLinearModels.jl",
    ]

for test in tests
    @testset "$test" begin
        include(test)
    end
end

DocMeta.setdocmeta!(
    ModelSummaries,
    :DocTestSetup,
    quote
        using ModelSummaries
    end;
    recursive=true
)

# NOTE: Doctests are skipped until source file doctests are updated
# (they reference old package name ModelSummarys instead of ModelSummaries)
@testset "Regression Tables Documentation" begin
    @test_skip "Doctests need updating for new package name"
end
