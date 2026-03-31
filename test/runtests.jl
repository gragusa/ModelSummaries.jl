using ModelSummaries
using Test

include("Aqua.jl")

tests = [
    "label_transforms.jl",
    "modelsummaries.jl",
    "new_features.jl",
]

for test in tests
    @testset "$test" begin
        include(test)
    end
end
