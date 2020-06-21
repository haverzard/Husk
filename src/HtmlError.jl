struct ParseError <: Exception
    position::UInt
    mode::PARSE_MODE
end