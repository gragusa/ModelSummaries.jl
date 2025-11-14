#=
This tests whether changes to defaults work as intended

These are difficult to test elsewhere since they are global changes
which have the possibility to impact other tests if not within their
own test set
=#

using RegressionTables2
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

RegressionTables2.default_digits(::RegressionTables2.AbstractRenderType, x::RegressionTables2.AbstractRegressionStatistic) = 4
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)

@test tab[3, 2] == "6.526***" # rr1 intercept coefficient
@test tab[8, end] == "(0.321)" # rr7 petalLength stdError
@test tab[18, 4] == "0.8673" # rr3 R2

RegressionTables2.default_digits(render::RegressionTables2.AbstractRenderType, x::RegressionTables2.AbstractRegressionStatistic) = RegressionTables2.default_digits(render, RegressionTables2.value(x))
##
RegressionTables2.default_digits(::RegressionTables2.AbstractAscii, x::RegressionTables2.AbstractUnderStatistic) = 4
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)
@test tab[3, 2] == "6.526***" # rr1 intercept coefficient
@test tab[8, end] == "(0.3210)" # rr7 petalLength stdError
@test tab[18, 4] == "0.867" # rr3 R2

tab2 = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7, backend = :latex)

@test tab2[8, end] == "(0.321)"

RegressionTables2.default_digits(render::RegressionTables2.AbstractAscii, x::RegressionTables2.AbstractUnderStatistic) = RegressionTables2.default_digits(render, RegressionTables2.value(x))

##

RegressionTables2.default_digits(::RegressionTables2.AbstractRenderType, x::RegressionTables2.CoefValue) = 2

@test tab[3, 2] == "6.53***" # rr1 intercept coefficient
@test tab[8, end] == "(0.321)" # rr7 petalLength stdError
@test tab[18, 4] == "0.867" # rr3 R2

RegressionTables2.default_digits(render::RegressionTables2.AbstractRenderType, x::RegressionTables2.CoefValue) = RegressionTables2.default_digits(render, RegressionTables2.value(x))

##

RegressionTables2.default_digits(::RegressionTables2.AbstractRenderType, x) = 4

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)

@test tab[3, 2] == "6.5262***" # rr1 intercept coefficient
@test tab[8, end] == "(0.3210)" # rr7 petalLength stdError
@test tab[18, 4] == "0.8673" # rr3 R2

RegressionTables2.default_digits(::RegressionTables2.AbstractRenderType, x) = 3

##

RegressionTables2.default_align(::RegressionTables2.AbstractRenderType) = :c

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)
@test tab.body_align == [:l, :c, :c, :c, :c, :c, :c, :c]

RegressionTables2.default_align(render::RegressionTables2.AbstractRenderType) = :r

##

RegressionTables2.default_header_align(::RegressionTables2.AbstractRenderType) = :l

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)
@test all(tab.header_align[2:end] .== :l)  # First column is always :l for labels

RegressionTables2.default_header_align(render::RegressionTables2.AbstractRenderType) = :c

##

@test tab[1, 2] == "SepalLength"

RegressionTables2.default_depvar(::RegressionTables2.AbstractRenderType) = false

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)

@test tab[1, 2] == "(1)"

RegressionTables2.default_depvar(::RegressionTables2.AbstractRenderType) = true

##

RegressionTables2.default_number_regressions(render::RegressionTables2.AbstractRenderType, rrs) = false

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)
@test tab[2, 2] == "6.526***"

RegressionTables2.default_number_regressions(render::RegressionTables2.AbstractRenderType, rrs) = length(rrs) > 1

##

RegressionTables2.default_print_fe(render::RegressionTables2.AbstractRenderType, rrs) = false

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)

@test tab[13, 1] == "Estimator"
@test tab[14, 1] == "N"

RegressionTables2.default_print_fe(render::RegressionTables2.AbstractRenderType, rrs) = true

##

RegressionTables2.default_keep(render::RegressionTables2.AbstractRenderType, rrs) = [1:3]
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)
@test size(tab, 1) == 18

RegressionTables2.default_keep(render::RegressionTables2.AbstractRenderType, rrs) = String[]

##

RegressionTables2.default_drop(render::RegressionTables2.AbstractRenderType, rrs) = [1:3]
tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)
@test size(tab, 1) == 16

RegressionTables2.default_drop(render::RegressionTables2.AbstractRenderType, rrs) = String[]

##

RegressionTables2.default_order(render::RegressionTables2.AbstractRenderType, rrs) = ["PetalLength"]

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)
@test tab[3, 1] == "PetalLength"

RegressionTables2.default_order(render::RegressionTables2.AbstractRenderType, rrs) = String[]

##

RegressionTables2.default_fixedeffects(render::RegressionTables2.AbstractRenderType, rrs) = [r"Species"]

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)
@test size(tab, 1) == 20

RegressionTables2.default_fixedeffects(render::RegressionTables2.AbstractRenderType, rrs) = String[]

##

RegressionTables2.default_labels(render::RegressionTables2.AbstractRenderType, rrs) = Dict("SepalLength" => "Sepal Length")

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)

@test tab[11, 1] == "Sepal Length"
@test tab[9, 1] == "PetalWidth"

RegressionTables2.default_labels(render::RegressionTables2.AbstractRenderType, rrs) = Dict{String, String}()

##

RegressionTables2.default_below_statistic(render::RegressionTables2.AbstractRenderType) = TStat

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)
@test tab[4, 2] == "(13.628)"
@test tab[6, 3] == "(5.310)"

RegressionTables2.default_below_statistic(render::RegressionTables2.AbstractRenderType) = StdError

##

RegressionTables2.default_stat_below(render::RegressionTables2.AbstractRenderType) = false

tab = modelsummary(rr1, rr2, rr3, rr4, rr5, rr6, rr7)

@test tab[3, 2] == "6.526*** (0.479)"

RegressionTables2.default_stat_below(render::RegressionTables2.AbstractRenderType) = true

##

RegressionTables2.label_p(render::RegressionTables2.AbstractRenderType) = "P"
RegressionTables2.interaction_combine(render::RegressionTables2.AbstractRenderType) = " x "
RegressionTables2.wrapper(render::RegressionTables2.AbstractLatex, s) = "\$^{$s}\$"
RegressionTables2.interaction_combine(render::RegressionTables2.AbstractLatex) = " \\& "
RegressionTables2.categorical_equal(render::RegressionTables2.AbstractLatex) = " ="

rr1 = reg(df, @formula(SepalLength ~ SepalWidth))
rr2 = reg(df, @formula(SepalLength ~ SepalWidth + PetalLength + Species))
rr3 = reg(df, @formula(SepalLength ~ SepalWidth * PetalLength + PetalWidth + fe(Species) + fe(isSmall)))

tab = modelsummary(rr1, rr2, rr3; regression_statistics=[Nobs, R2, FStatPValue])

@test tab[21, 1] == "F-test P value"
@test tab[15, 1] == "SepalWidth x PetalLength"
@test tab[11, 1] == "Species: virginica"

tab = modelsummary(rr1, rr2, rr3; regression_statistics=[Nobs, R2, FStatPValue], render=LatexTable())

@test tab[21, 1] == "\$F\$-test \$P\$ value"
@test tab[15, 1] == "SepalWidth \\& PetalLength"
@test tab[11, 1] == "Species = virginica"

RegressionTables2.label_p(render::RegressionTables2.AbstractRenderType) = "p"
RegressionTables2.interaction_combine(render::RegressionTables2.AbstractRenderType) = " & "
RegressionTables2.wrapper(render::RegressionTables2.AbstractLatex, s) = s
RegressionTables2.interaction_combine(render::RegressionTables2.AbstractLatex) = " \$\\times\$ "
RegressionTables2.categorical_equal(render::RegressionTables2.AbstractLatex) = ":"