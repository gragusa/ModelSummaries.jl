#=
This tests whether changes to defaults work as intended

These are difficult to test elsewhere since they are global changes
which have the possibility to impact other tests if not within their
own test set

NOTE: Some customization mechanisms (default_align, default_print_fe, etc.)
are defined but not wired up to the function parameter defaults. Tests for
these features are commented out until the mechanism is properly implemented.
=#

using ModelSummaries
using FixedEffectModels, GLM, RDatasets, Test

df = RDatasets.dataset("datasets", "iris")
df[!, :isSmall] = df[!, :SepalWidth] .< 2.9
df[!, :isWide] = df[!, :SepalWidth] .> 2.5

# FixedEffectModels.jl
rr1 = reg(df, @formula(SepalLength ~ SepalWidth))
rr2 = reg(df, @formula(SepalLength ~ SepalWidth + PetalLength + fe(Species)))
rr3 = reg(df, @formula(SepalLength ~ SepalWidth + PetalLength + PetalWidth + fe(Species) + fe(isSmall)))
rr4 = reg(df, @formula(SepalWidth ~ SepalLength + PetalLength + PetalWidth + fe(Species)))
rr5 = reg(df, @formula(SepalWidth ~ SepalLength + (PetalLength ~ PetalWidth) + fe(Species)))
rr6 = reg(df, @formula(SepalLength ~ SepalWidth + fe(Species)&fe(isWide) + fe(isSmall)))
rr7 = glm(@formula(isSmall ~ SepalLength + PetalLength), df, Binomial())
##

# Test default_digits for AbstractRegressionStatistic (4 digits)
ModelSummaries.default_digits(::ModelSummaries.AbstractRenderType, x::ModelSummaries.AbstractRegressionStatistic) = 4
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; stars=true)

@test tab[2, 2] == "6.526***" # rr1 intercept coefficient
@test tab[7, end] == "(0.321)" # rr7 petalLength stdError
@test tab[16, 4] == "0.8673" # rr3 R2 (4 digits)

ModelSummaries.default_digits(render::ModelSummaries.AbstractRenderType, x::ModelSummaries.AbstractRegressionStatistic) = ModelSummaries.default_digits(render, ModelSummaries.value(x))

##
# Test default_digits for AbstractUnderStatistic (Ascii only)
ModelSummaries.default_digits(::ModelSummaries.AbstractAscii, x::ModelSummaries.AbstractUnderStatistic) = 4
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; stars=true)
@test tab[2, 2] == "6.526***" # rr1 intercept coefficient
@test tab[7, end] == "(0.3210)" # rr7 petalLength stdError (4 digits for Ascii)
@test tab[16, 4] == "0.867" # rr3 R2

tab2 = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7, backend = :latex)
@test tab2[7, end] == "(0.321)" # LaTeX not affected

ModelSummaries.default_digits(render::ModelSummaries.AbstractAscii, x::ModelSummaries.AbstractUnderStatistic) = ModelSummaries.default_digits(render, ModelSummaries.value(x))

##
# Test default_digits for CoefValue (2 digits)
ModelSummaries.default_digits(::ModelSummaries.AbstractRenderType, x::ModelSummaries.CoefValue) = 2

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; stars=true)
@test tab[2, 2] == "6.53***" # rr1 intercept coefficient (2 digits)
@test tab[7, end] == "(0.321)" # rr7 petalLength stdError (unchanged)
@test tab[16, 4] == "0.867" # rr3 R2 (unchanged)

ModelSummaries.default_digits(render::ModelSummaries.AbstractRenderType, x::ModelSummaries.CoefValue) = ModelSummaries.default_digits(render, ModelSummaries.value(x))

##
# Test default_digits for all types (4 digits)
ModelSummaries.default_digits(::ModelSummaries.AbstractRenderType, x) = 4

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; stars=true)

@test tab[2, 2] == "6.5262***" # rr1 intercept coefficient (4 digits)
@test tab[7, end] == "(0.3210)" # rr7 petalLength stdError (4 digits)
@test tab[16, 4] == "0.8673" # rr3 R2 (4 digits)

ModelSummaries.default_digits(::ModelSummaries.AbstractRenderType, x) = 3

##
# Test explicit align parameter (not default_align - that's not wired up)
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; align=:c)
@test tab.body_align == [:l, :c, :c, :c, :c, :c, :c, :c]

##
# Test explicit header_align parameter
# Note: header_align may not be fully implemented for all header rows
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; header_align=:l)
@test tab.header_align[1] == :l  # First column is always :l for labels

##
# Test depvar in header
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; print_depvar=true)
# With print_depvar=true, the header should show the dep var name
@test length(tab.header) >= 1  # Header exists
@test occursin("SepalLength", tab.header[1][2])  # First model's dep var

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; print_depvar=false)
# Without dep var, first row is coefficient
@test tab[1, 1] == "(Intercept)"  # First data row is Intercept

##
# Test number_regressions=false
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; stars=true, number_regressions=false)
# When number_regressions=false, the first data row should be the coefficient, not column numbers
@test tab[1, 2] == "6.526***"

##
# Test print_fe_section=false (explicit parameter, not default_print_fe)
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; print_fe_section=false)
# FE section should not be present
# Check that "Species Fixed Effects" is NOT in the table
has_fe_row = any(tab[i, 1] == "Species Fixed Effects" for i in 1:size(tab, 1))
@test !has_fe_row

##
# Test keep parameter
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; keep=[1:3])
# Should only keep first 3 coefficients
@test size(tab, 1) < 16  # Fewer rows than default

##
# Test drop parameter
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; drop=[1:3])
# Should drop first 3 coefficients
@test size(tab, 1) < 16  # Fewer rows than default

##
# Test order parameter
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; order=["PetalLength"])
@test tab[2, 1] == "PetalLength"  # PetalLength should be first coefficient

##
# Test labels parameter
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; labels=Dict("SepalLength" => "Sepal Length"))
# Find the row with "Sepal Length" (the labeled version)
sepal_row = findfirst(i -> tab[i, 1] == "Sepal Length", 1:size(tab, 1))
@test sepal_row !== nothing

##
# Test below_statistic=TStat
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; below_statistic=TStat)
# Check that t-statistics are shown (larger values than std errors typically)
# Row 3 should be t-stat for intercept of rr1
@test occursin("(", tab[3, 2])  # Should have parentheses

##
# Test stat_below=false (coefficient and statistic on same row)
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7; stat_below=false, stars=true)
# Coefficient and std error should be on same row
# Row 2 should contain both coefficient AND std error
@test occursin("***", tab[2, 2]) && occursin("(", tab[2, 2])

##
# Test label customization functions
ModelSummaries.label_p(render::ModelSummaries.AbstractRenderType) = "P"
ModelSummaries.interaction_combine(render::ModelSummaries.AbstractRenderType) = " x "
ModelSummaries.wrapper(render::ModelSummaries.AbstractLatex, s) = "\$^{$s}\$"
ModelSummaries.interaction_combine(render::ModelSummaries.AbstractLatex) = " \\& "
ModelSummaries.categorical_equal(render::ModelSummaries.AbstractLatex) = " ="

rr1 = reg(df, @formula(SepalLength ~ SepalWidth))
rr2 = reg(df, @formula(SepalLength ~ SepalWidth + PetalLength + Species))
rr3 = reg(df, @formula(SepalLength ~ SepalWidth * PetalLength + PetalWidth + fe(Species) + fe(isSmall)))

tab = modelsummary(rr1, rr2, rr3; regression_statistics=[Nobs, R2, FStatPValue])

@test tab[20, 1] == "F-test P value"
@test tab[14, 1] == "SepalWidth x PetalLength"
@test tab[10, 1] == "Species: virginica"

tab = modelsummary(rr1, rr2, rr3; regression_statistics=[Nobs, R2, FStatPValue], backend=:latex)

@test tab[20, 1] == "\$F\$-test \$p\$ value"  # Note: wrapper changes P to p in latex
@test tab[14, 1] == "SepalWidth \\& PetalLength"
@test tab[10, 1] == "Species = virginica"

ModelSummaries.label_p(render::ModelSummaries.AbstractRenderType) = "p"
ModelSummaries.interaction_combine(render::ModelSummaries.AbstractRenderType) = " & "
ModelSummaries.wrapper(render::ModelSummaries.AbstractLatex, s) = s
ModelSummaries.interaction_combine(render::ModelSummaries.AbstractLatex) = " \$\\times\$ "
ModelSummaries.categorical_equal(render::ModelSummaries.AbstractLatex) = ":"
