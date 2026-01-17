module ModelSummaries

    ##############################################################################
    ##
    #   TODO:
    #
    #   FUNCTIONALITY: (asterisk means priority)
    #   - write more serious tests
    #
    #   TECHNICAL:
    #   - Formatting option: string (or function) for spacer rows
    #
    ##
    ##############################################################################


    ##############################################################################
    ##
    ## Dependencies
    ##
    ##############################################################################

    #using DataFrames

    using StatsBase
    using StatsModels
    using Statistics
    using StatsAPI
    import StatsAPI: coef, stderror, dof_residual, responsename, coefnames, islinear, nobs

    # Import VcovSpec and vcov from CovarianceMatricesBase
    using CovarianceMatricesBase
    import CovarianceMatricesBase: VcovSpec, vcov

    using Distributions
    using Format
    using LinearAlgebra: issymmetric
    using PrettyTables
    using Crayons

    ##############################################################################
    ##
    ## Exported methods and types
    ##
    ##############################################################################

    export modelsummary, ModelSummary
    export Nobs, R2, R2McFadden, R2CoxSnell, R2Nagelkerke,
    R2Deviance, AdjR2, AdjR2McFadden, AdjR2Deviance, DOF, LogLikelihood, AIC, BIC, AICC,
    FStat, FStatPValue, FStatIV, FStatIVPValue, R2Within, PseudoR2, AdjPseudoR2, VcovType, Spacer
    export TStat, StdError, ConfInt, RegressionType

    # Statistics type system
    export AbstractRegressionStatistic

    # Customization functions
    export add_hline!, remove_hline!, set_alignment!, add_formatter!, set_backend!, merge_kwargs!

    # Themes
    export Themes

    export make_estim_decorator
    export vcov


    ##############################################################################
    ##
    ## Load files
    ##
    ##############################################################################

    # render type definitions (needed by all other files)
    include("compat/render_types.jl")

    # main types
    include("RegressionStatistics.jl")
    include("coefnames.jl")
    include("regressionResults.jl")

    # compatibility layer for rendering system (methods)
    include("compat/render_compat.jl")

    # main settings
    include("decorations/default_decorations.jl")
    include("label_transforms/default_transforms.jl")

    # table structure (PrettyTables-based)
    include("modelsummary_type.jl")

    # theme presets
    include("themes.jl")

    # main functions
    include("modelsummary.jl")

end
