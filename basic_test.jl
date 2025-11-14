using DataFrames
using GLM
using ModelSummaries

df = DataFrame(
    y = rand(100),
    w = rand(100),
    x1 = rand(100),
    x2 = rand(100),
    x3 = rand(100),
    z = repeat(1:2, inner=50)
)

lm1 = lm(@formula(y ~ x1 + x2 + x3), df)
lm2 = lm(@formula(y ~ x1 + x2), df)
lm3 = lm(@formula(y ~ x1 + z), df)

modelsummary(lm1, lm2, lm3)
