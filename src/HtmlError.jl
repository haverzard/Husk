struct ParseError <: Exception
    position::Int
    mode::PARSE_MODE
end

struct CloseTokenError <: Exception
    position::Int
end