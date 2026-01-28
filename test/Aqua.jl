using Test
using Aqua
using ModelSummaries

@testset "Aqua.jl" begin
    # Test ambiguities separately with recursive=false since some dependencies
    # may have ambiguities that would cause the test to fail
    Aqua.test_ambiguities(ModelSummaries; recursive = false)

    # Run all other Aqua tests
    # - piracies=false: vcov(spec) causes intentional type piracy that will
    #   move to CovarianceMatrices.jl in the future
    # - stale_deps=false: extension trigger packages (CovarianceMatrices,
    #   FixedEffectModels, GLM) are in [deps] for extensions but appear
    #   "stale" to Aqua since the main module doesn't directly use them
    Aqua.test_all(ModelSummaries; ambiguities = true, piracies = true, stale_deps = true)
end
