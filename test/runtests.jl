using ModelSummaries
using Test

include("Aqua.jl")
include("ExplicitImports.jl")

tests = [
    "label_transforms.jl",
    "modelsummaries.jl",
    "new_features.jl",
    "statistics_errors.jl",
    "input_validation.jl",
    "vcov.jl",
    "inference.jl"
]

for test in tests
    @testset "$test" begin
        include(test)
    end
end
