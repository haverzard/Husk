# Husk
![travis-ci](https://travis-ci.com/haverzard/Husk.svg?token=Y6R1oCz891w1Si7ewrbX&branch=master)

A simple HTML tokenizer library using Julia.

## Usage
### Activate/Add husk
Run `activate .` or `add https://github.com/haverzard/Husk` in julia pkg

### Import husk
Run `import Husk` in julia

### Tokenizer
Run `Husk.tokenizer("html_string_here")` and it will return a token stack.

For example:

`julia> Husk.tokenizer("<Test>World!</Test>Hello<Test/>")`

will output

`Husk.TokenStack(["TOKEN_TEST", "CONTENT", "TOKEN_END_TEST", "CONTENT", "SINGLE_TOKEN_TEST"], 5)`

### Checker
Run `Husk.check(token_stack)` and it will return `true` if syntax is valid and `false` if syntax is invalid.


For example:

`julia> Husk.check(Husk.tokenizer("<Test>World!</Test>Hello<Test/>"))`

will output

`true`

### Deserialize
Run `Husk.convert_tojson(html_string_here)` and it will return a HtmlJSON or throws an exception if error occurred.

For example:

`julia> Husk.convert_tojson("<Test>World!</Test>Hello<Test/>")`

will output

`Main.Husk.HtmlJSON("WRAPPER", Dict{String,Any}(), Any[Main.Husk.HtmlJSON("test", Dict{String,Any}(), Any["World!"]), "Hello", Main.Husk.HtmlJSON("test", Dict{String,Any}(), Any[])])`

## Features
- [X] Tokenizer
- [X] Syntax Checker
- [X] JSON/Tree Representation
- [x] Deserialize to json
- [X] Serialize from json
- [x] Supports script (not checking javascript though)
- [x] Supports style (not checking css though)
- [x] Supports singleton
- [X] Supports custom singleton
- [X] Supports some front-end syntaxes
- [ ] Children-Parent List Representation
- [ ] And more coming soon...

## License
[MIT](https://github.com/haverzard/Husk/blob/master/LICENSE)