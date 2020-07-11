using Test
using Husk

@test Husk.check(Husk.tokenizer("<Test>World!</Test>Hello<Test/>")) == true

@test Husk.convert_tojson("<Test>World!</Test>Hello<Test/>") == Main.Husk.HtmlJSON("WRAPPER", Dict{String,Any}(), Any[Main.Husk.HtmlJSON("test", Dict{String,Any}(), Any["World!"]), "Hello", Main.Husk.HtmlJSON("test", Dict{String,Any}(), Any[])])