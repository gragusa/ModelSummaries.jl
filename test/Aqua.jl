using Test
using Aqua
using ModelSummaries

@testset "Aqua.jl" begin
    Aqua.test_all(ModelSummaries)
end
