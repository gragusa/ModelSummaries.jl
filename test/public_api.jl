using Test
using ModelSummaries

const EXTENSION_API = [
    :AbstractRegressionData, :AbstractUnderStatistic, :AbstractR2,
    :label, :value, :applies, :default_regression_statistics, :default_section_order,
    :inference_coeftable, :with_teststatcol, :reference_distribution,
    :other_stats, :fixed_effect_entries, :cluster_entries,
    :can_standardize, :standardize_coef_values, :vcov_type_name,
    :CoefValue, :HasControls, :FixedEffectValue, :ClusterValue, :FirstStageValue,
    :get_coefname, :display_name, :significance_stars,
    :fe_suffix, :cluster_suffix, :first_stage_suffix,
    :AbstractCoefName, :CoefName, :InteractedCoefName, :CategoricalCoefName,
    :InterceptCoefName, :FixedEffectCoefName, :ClusterCoefName, :FirstStageCoefName]

@testset "extension API is public and documented" begin
    declared = filter(
        n -> Base.ispublic(ModelSummaries, n) &&
             !Base.isexported(ModelSummaries, n),
        names(ModelSummaries; all = true))
    @test sort(declared) == sort(EXTENSION_API)
    for n in EXTENSION_API
        @test Docs.hasdoc(ModelSummaries, n)
    end
end
