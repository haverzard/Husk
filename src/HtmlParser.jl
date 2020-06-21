@enum PARSE_MODE READ_START READ_TAG READ_ATTR READ_ATTR_CONTENT READ_CLOSE_TAG READ_STRING READ_NUM READ_BOOLEAN READ_TAG_CONTENT

mutable struct TokenStack
    array::Array{String,1}
    size::UInt
end

function push(stack::TokenStack, value::String)
    push!(stack.array, value)
    stack.size += 1
end

function pop(stack::TokenStack)::String
    if stack.size > 0
        stack.size -= 1
        return pop!(stack.array)
    else
        return ""
    end
end

function tokenizer_keep_contents(html::String)::TokenStack
    stack = TokenStack(String[], 0)
    mode = READ_TAG_CONTENT
    store = ""
    store2 = ""
    for c in html
        if mode == READ_TAG_CONTENT
            if c == '<'
                if store != ""
                    push(stack, store)
                end
                store = "<"
                store2 = ""
                mode = READ_TAG
            elseif c == '\n' || c == '\r' || c == '\t'
                # Ignore too
            elseif c == ' ' && store == ""
                # Ignore
            elseif c == ' '
                store2 = string(store2, " ")
            else
                if store2 != ""
                    store = string(store, store2)
                    store2 = ""
                end
                store = string(store, c)
            end
        elseif mode == READ_TAG
            if c == '>'
                store = string(store, c)
                push(stack, store)
                store = ""
                mode = READ_TAG_CONTENT
            else
                store = string(store, c)
            end
        end
    end
    if store != ""
        push(stack, store)
    end
    return stack
end

function tokenizer(html::String)::TokenStack
    stack = TokenStack(String[], 0)
    mode = READ_TAG_CONTENT
    store = ""
    store2 = ""
    alphanum = r"[0-9a-zA-Z]"
    num = r"[1-9]"
    has_content = false
    has_error = false
    has_temp_error = false
    for c in html
        if mode == READ_START
            if c == '<'
                if has_error
                    push(stack, "BAD_TOKEN")
                end
                store = "TOKEN_"
                has_content = false
                mode = READ_TAG
            else
                has_error = true
            end
        elseif mode == READ_TAG_CONTENT
            if c == '<'
                if has_content
                    push(stack, "CONTENT")
                end
                store = "TOKEN_"
                has_content = false
                mode = READ_TAG
            else
                has_content = true
            end
        else
            if c == '>'
                if store != "TOKEN_" && !has_error && !has_temp_error && mode != READ_ATTR_CONTENT && (mode != READ_STRING || has_content)
                    push(stack, store)
                else
                    push(stack, "BAD_TOKEN")
                end
                store = ""
                store2 = ""
                has_error = false
                has_temp_error = false
                has_content = false
                mode = READ_TAG_CONTENT
            elseif mode == READ_TAG
                if c == '/' && store == "TOKEN_"
                    store = string(store, "END_")
                elseif occursin(alphanum, string(c))
                    store = string(store, uppercase(c))
                    has_content = true
                elseif c == ' ' && has_content
                    has_content = false
                    mode = READ_ATTR
                else
                    has_error = true
                end
            elseif mode == READ_ATTR
                if occursin(alphanum, string(c))
                    has_content = true
                elseif c == '=' && has_content
                    mode = READ_ATTR_CONTENT
                    has_content = false
                elseif !(c == ' ')
                    has_error = true
                end
            elseif mode == READ_ATTR_CONTENT
                if occursin(r"[a-zA-Z]", string(c))
                    has_temp_error = true
                    store2 = string(c)
                    mode = READ_BOOLEAN
                elseif c == '"' || c == '\''
                    mode = READ_STRING
                    store2 = string(c)
                elseif occursin(num, string(c))
                    mode = READ_NUM
                else
                    has_error = true
                end
            elseif mode == READ_BOOLEAN
                if occursin(r"[falstrue]", string(c))
                    store2 = string(store2, c)
                    print("x")
                    has_temp_error = store2 != "false" && store2 != "true"
                elseif c == ' '
                    store2 = ""
                    has_error = has_error || has_temp_error
                    has_temp_error = false
                    mode = READ_ATTR
                else
                    has_temp_error = true
                end
            elseif mode == READ_NUM
                if c == '.' && !has_content
                    has_content = true
                elseif c == ' ' && !has_error
                    has_content = false
                    mode = READ_ATTR
                elseif !occursin(num, string(c))
                    has_error = true
                end
            elseif mode == READ_STRING
                if c == store2[begin]
                    if !has_temp_error
                        has_content = true
                    end
                elseif c == ' '
                    has_error = has_error || has_temp_error
                    has_temp_error = false
                    has_content = false
                    mode = READ_ATTR
                elseif c == '\\'
                    has_temp_error = !has_temp_error
                elseif occursin(r"[abfnrtv]", string(c)) && has_temp_error
                    has_temp_error = false
                elseif has_content
                    has_error = true
                end
            end
        end
    end
    if mode == READ_TAG_CONTENT
        if has_content
            push(stack, "CONTENT")
        end
    else
        push(stack, "BAD_TOKEN")
    end
    return stack
end

function check(stack::TokenStack)::Bool
    store_stack = TokenStack(String[], 0)
    has_error = false
    for token in stack.array
        if token == "BAD_TOKEN"
            has_error = true
            break
        elseif occursin(r"TOKEN_END_", token)
            if pop(store_stack) != string("TOKEN_", token[11:end])
                has_error = true
                break
            end
            has_error = false
        elseif token != "CONTENT"
            push(store_stack, token)
            has_error = true
        end
    end
    return !has_error
end

struct HtmlJSON
    tag::String
    attributes::Dict{String,Any}
    children::Array{Any,1}
end

function init_HtmlJSON(tag::String)::HtmlJSON
    return HtmlJSON(tag, Dict(), Any[])
end

function convert_tojson(html::String)::HtmlJSON
    temp, _ = convert_tojson_rec("TEMP", html, 0, READ_START)
    return temp.children[1]
end

function convert_tojson_rec(tag::String, html::String, position::Int, mode::PARSE_MODE)::Tuple{HtmlJSON, Int}
    result = init_HtmlJSON(tag)
    store = ""
    store2 = ""
    alphanum = r"[0-9a-zA-Z]"
    num = r"[1-9]"
    has_content = false
    has_temp_error = false
    while position < length(html)
        position += 1
        c = html[position]
        if mode == READ_START
            if c == '<'
                mode = READ_TAG
            else
                throw(ParseError(position, mode))
            end
        elseif mode == READ_TAG_CONTENT
            if c == '<'
                if store != ""
                    push!(result.children, store)
                end
                store = ""
                store2 = ""
                mode = READ_TAG
            elseif c == '\n' || c == '\r' || c == '\t'
                # Ignore too
            elseif c == ' ' && store == ""
                # Ignore
            elseif c == ' '
                store2 = string(store2, " ")
            else
                if store2 != ""
                    store = string(store, store2)
                    store2 = ""
                end
                store = string(store, c)
            end
        else
            if mode == READ_TAG
                if c == '>'
                    if !has_content
                        temp, position = convert_tojson_rec(store, html, position, READ_TAG_CONTENT)
                        push!(result.children, temp)
                    else
                        if store != result.tag
                            throw(CloseTokenError(position))
                        end
                        return (result, position)
                    end
                    store = ""
                    store2 = ""
                    has_temp_error = false
                    has_content = false
                    mode = READ_TAG_CONTENT
                elseif c == '/' && !has_content
                    has_content = true
                elseif occursin(alphanum, string(c))
                    store = string(store, c)
                elseif c == ' ' && store != "" && !has_content
                    if !has_content
                        temp, position = convert_tojson_rec(store, html, position, READ_ATTR)
                        push!(result.children, temp)
                    else
                        return (result, position)
                    end
                    has_content = false
                    store = ""
                    mode = READ_TAG_CONTENT
                else
                    throw(ParseError(position, mode))
                end
            elseif c == '>'
                if has_temp_error || mode == READ_ATTR_CONTENT
                    throw(ParseError(position, mode))
                end

                if mode == READ_STRING
                    if !has_content
                        throw(ParseError(position, mode))
                    end
                    result.attributes[store] = store2[begin+1:end-1]
                elseif mode == READ_NUM
                    if has_content
                        result.attributes[store] = parse(Float64, store2)
                    else
                        result.attributes[store] = parse(Int, store2)
                    end
                else
                    result.attributes[store] = store2 == "true"
                end
                store = ""
                store2 = ""
                has_temp_error = false
                has_content = false
                mode = READ_TAG_CONTENT
            elseif mode == READ_ATTR
                if occursin(alphanum, string(c))
                    store = string(store, c)
                elseif c == '=' && store != ""
                    mode = READ_ATTR_CONTENT
                elseif c == ' '
                    result.attributes[store] = ""
                    store = ""
                else
                    throw(ParseError(position, mode))
                end
            elseif mode == READ_ATTR_CONTENT
                if occursin(r"[a-zA-Z]", string(c))
                    store2 = string(c)
                    has_temp_error = true
                    mode = READ_BOOLEAN
                elseif c == '"' || c == '\''
                    store2 = string(c)
                    mode = READ_STRING
                elseif occursin(num, string(c))
                    store2 = string(c)
                    mode = READ_NUM
                else
                    throw(ParseError(position, mode))
                end
            elseif mode == READ_BOOLEAN
                if occursin(r"[falstrue]", string(c))
                    store2 = string(store2, c)
                    has_temp_error = store2 != "false" && store2 != "true"
                elseif c == ' '
                    if has_temp_error
                        throw(ParseError(position, mode))
                    end
                    result.attributes[store] = store2 == "true"
                    store = ""
                    store2 = ""
                    mode = READ_ATTR
                else
                    has_temp_error = true
                end
            elseif mode == READ_NUM
                if c == '.' && !has_content
                    store2 = string(store2, c)
                    has_content = true
                elseif c == ' ' && !has_temp_error
                    if has_temp_error
                        throw(ParseError(position, mode))
                    end
                    if has_content
                        result.attributes[store] = parse(Float64, store2)
                    else
                        result.attributes[store] = parse(Int, store2)
                    end
                    store = ""
                    store2 = ""
                    has_content = false
                    mode = READ_ATTR
                elseif occursin(num, string(c))
                    store2 = string(store2, c)
                else
                    has_temp_error = true
                end
            elseif mode == READ_STRING
                if c == store2[begin]
                    if !has_temp_error
                        has_content = true
                    end
                elseif c == ' '
                    if has_temp_error || !has_content
                        throw(ParseError(position, mode))
                    end
                    result.attributes[store] = store2[begin+1:end-1]
                    store = ""
                    store2 = ""
                    has_content = false
                    mode = READ_ATTR
                elseif c == '\\'
                    store2 = string(store2, c)
                    has_temp_error = !has_temp_error
                elseif occursin(r"[abfnrtv]", string(c)) && has_temp_error
                    store2 = string(store2, c)
                    has_temp_error = false 
                elseif has_content
                    throw(ParseError(position, mode))
                else
                    store2 = string(store2, c)
                end
            end
        end
    end
    if mode != READ_TAG_CONTENT || store != ""
        throw(ParseError(position, mode))
    end
    return (result, position)
end