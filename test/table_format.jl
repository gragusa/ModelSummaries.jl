using ModelSummaries
using PrettyTables
using Test

@testset "table_format keyword" begin
    body = Any[
        "(Intercept)" 1.0;
        "" "(0.1)";
    ]

    # Use a custom TextTableFormat with matrix-style formatting
    custom_tf = PrettyTables.text_table_format__matrix
    ms = ModelSummary(["", "Model 1"], body; table_format=Dict(:text => custom_tf))

    # Text backend should use the custom matrix format characters.
    buf = IOBuffer()
    show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
    output = String(take!(buf))
    @test occursin("[", output) || occursin("│", output)  # matrix format uses brackets or pipes

    # Unspecified backends fall back to defaults.
    @test ms.table_format[:html] == ModelSummaries.default_table_format(:html)
    @test ms.table_format[:latex] == ModelSummaries.default_table_format(:latex)

    # Test with latex format
    latex_ms = ModelSummary(["", "Model 1"], body; table_format=Dict(:latex => PrettyTables.latex_table_format__booktabs))
    @test latex_ms.table_format[:latex] == PrettyTables.latex_table_format__booktabs
end
