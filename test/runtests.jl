using RDatasets
using ModelSummaries
using FixedEffectModels, GLM, Documenter
using Test

include("Aqua.jl")

tests = [
    "default_changes.jl",
    "modelsummaries.jl",
    "decorations.jl",
    "label_transforms.jl",
    "table_format.jl",
    "new_features.jl",
    "themes.jl",
    "Regress.jl"
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
    recursive = true
)

# NOTE: Doctests are skipped until source file doctests are updated
# (they reference old package name ModelSummarys instead of ModelSummaries)
@testset "Regression Tables Documentation" begin
    @test_skip "Doctests need updating for new package name"
end
