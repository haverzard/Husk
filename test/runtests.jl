using Test
using Husk

@test Husk.check(Husk.tokenizer("<Test>World!</Test>Hello<Test/>")) == true

@test_nowarn Husk.convert_tojson("<Test>World!</Test>Hello<Test/>")