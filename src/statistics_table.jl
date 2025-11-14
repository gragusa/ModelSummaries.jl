"""
    statistics_matrix(rrs, stats)

Compute the bottom-panel regression statistics for the provided models and return
them as a matrix where the first column contains the statistic labels and the remaining
columns contain the values for each model.
"""
function statistics_matrix(rrs, stats)
    return combine_statistics(rrs, stats)
end

display_val(x::Pair) = last(x)
display_val(x::Type) = x
f_val(x::Pair) = first(x)
f_val(x::Type) = x

"""
    combine_statistics(tables, stats)

Takes a set of tables (RegressionModels) and a vector of `AbstractRegressionStatistic`.
The `stats` argument can also be a pair of `AbstractRegressionStatistic => String`, which
uses the second value as the name of the statistic in the final table.
"""
function combine_statistics(tables, stats)
    types_strings = display_val.(stats)
    type_f = f_val.(stats)
    mat = Matrix{Any}(missing, length(types_strings), length(tables))
    for (i, t) in enumerate(tables)
        for (j, s) in enumerate(type_f)
            mat[j, i] = s(t)
        end
    end
    hcat(types_strings, mat)
end
