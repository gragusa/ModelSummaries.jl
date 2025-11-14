using ModelSummaries
using PrettyTables
using Test

@testset "table_format keyword" begin
    body = Any[
        "(Intercept)" 1.0;
        "" "(0.1)";
    ]

    custom_tf = PrettyTables.tf_unicode_rounded
    ms = ModelSummary(["", "Model 1"], body; table_format=Dict(:text => custom_tf))

    # Text backend should use the custom unicode frame characters.
    buf = IOBuffer()
    show(IOContext(buf, :limit => false), MIME("text/plain"), ms)
    output = String(take!(buf))
    @test occursin("╭", output)

    # Unspecified backends fall back to defaults.
    @test ms.table_format[:html] == ModelSummaries.default_table_format(:html)
    @test ms.table_format[:latex] == ModelSummaries.default_table_format(:latex)

    # Symbol aliases resolve to PrettyTables-defined formats.
    alias_ms = ModelSummary(["", "Model 1"], body; table_format=:unicode_rounded)
    @test alias_ms.table_format[:text] == PrettyTables.tf_unicode_rounded
end
