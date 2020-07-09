@enum PARSE_MODE READ_COMMENT READ_SCRIPT READ_STYLE READ_START READ_TAG READ_ATTR READ_ATTR_CONTENT READ_CLOSE_TAG READ_STRING READ_NUM READ_BOOLEAN READ_TAG_CONTENT

whitespaces = r"[\n\t\r]"
alphanum = r"[0-9a-zA-Z]"
num = r"[1-9]"
singleton = r"area|base|br|col|command|embed|hr|img|input|keygen|link|meta|param|source|track|wbr|!doctype"
alphabets = r"[a-zA-Z]"

mutable struct TokenStack
    array::Array{String,1}
    size::Int
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
            elseif occursin(whitespaces, string(c)) || (c == ' ' && store == "")
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
    counter = 0
    has_content = false
    has_error = false
    has_temp_error = false
    has_exclamation = false
    is_singleton = false
    is_closed = false
    is_script = false
    is_style = false
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
                has_content = !occursin(whitespaces, string(c)) || has_content
            end
        else
            if mode == READ_TAG
                if c == '>'
                    if !is_closed && store2 == "script"
                        mode = READ_SCRIPT
                    elseif !is_closed && store2 == "style"
                        mode = READ_STYLE
                    else
                        mode = READ_TAG_CONTENT
                    end
                    if occursin(singleton, store2) || is_closed || has_exclamation
                        store = string("SINGLE_", store)
                    end
                    if has_content && !has_error && counter == 0
                        push(stack, store)
                    else
                        push(stack, "BAD_TOKEN")
                    end
                    store = ""
                    store2 = ""
                    counter = 0
                    has_error = false
                    has_content = false
                    has_exclamation = false
                    is_closed = false
                elseif is_closed
                    has_error = true
                elseif c == '/'
                    if store == "TOKEN_"
                        store = string(store, "END_")
                        store2 = string(store2, c)
                    elseif !occursin(r"TOKEN_END", store)
                        is_closed = true
                    else
                        has_error = true
                    end
                elseif occursin(alphanum, string(c))
                    store = string(store, uppercase(c))
                    store2 = string(store2, c)
                    has_content = true
                elseif c == '!' && !has_content
                    has_exclamation = true
                elseif c == '-' && !has_content && has_exclamation
                    counter += 1
                    if counter == 2
                        has_exclamation = false
                        counter = 0
                        mode = READ_COMMENT
                    end
                elseif c == ' ' && has_content && store2[1] != '/' && !is_script && !is_style
                    is_script = store2 == "script"
                    is_style = store2 == "style"
                    has_content = false
                    is_singleton = occursin(singleton, store2)
                    store2 = ""
                    mode = READ_ATTR
                elseif c == ' ' && (is_script || is_style)
                    store = string(store, uppercase(c))
                else
                    has_error = true
                end
            elseif mode == READ_COMMENT
                if c == '-'
                    counter += 1
                else
                    if c == '>' && counter >= 2
                        push(stack, "COMMENT")
                        mode = READ_TAG_CONTENT
                    end
                    counter = 0
                end
            elseif mode == READ_SCRIPT
                if c == '<'
                    has_content = store2 != "" || has_content
                    store2 = ""
                elseif c == '>'
                    if store2 == "/script"
                        is_script = false
                        if has_content
                            push(stack, "CONTENT")
                        end
                        push(stack, "TOKEN_END_SCRIPT")
                        mode = READ_TAG_CONTENT
                        has_content = false
                    else
                        has_content = true
                    end
                    store2 = ""
                else
                    store2 = string(store2, c)
                    has_content = true
                end
            elseif mode == READ_STYLE
                if c == '<'
                    has_content = store2 != "" || has_content
                    store2 = ""
                elseif c == '>'
                    if store2 == "/style"
                        is_style = false
                        if has_content
                            push(stack, "CONTENT")
                        end
                        push(stack, "TOKEN_END_STYLE")
                        mode = READ_TAG_CONTENT
                        has_content = false
                    else
                        has_content = true
                    end
                    store2 = ""
                else
                    store2 = string(store2, c)
                    has_content = true
                end
            elseif c == '>'
                if is_singleton || has_exclamation
                    store = string("SINGLE_", store)
                end
                if (store != "TOKEN_" && !has_error && !has_temp_error && mode != READ_ATTR_CONTENT 
                    && (mode != READ_STRING || has_content) && counter == 0)
                    push(stack, store)
                else
                    push(stack, "BAD_TOKEN")
                end
                if !is_closed && is_script
                    mode = READ_SCRIPT
                elseif !is_closed && is_style
                    mode = READ_STYLE
                else
                    mode = READ_TAG_CONTENT
                end
                store = ""
                store2 = ""
                counter = 0
                has_error = false
                has_temp_error = false
                has_content = false
                has_exclamation = false
                is_singleton = false
                is_closed = false
                is_script = false
                is_style = false
            elseif c == '/' && (mode != READ_STRING || has_content)
                is_closed = true
                is_singleton = true
            elseif is_closed
                has_error = true
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
                if occursin(alphabets, string(c))
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
                if c != ' '
                    store2 = string(store2, c)
                    has_temp_error = store2 != "false" && store2 != "true"
                else
                    store2 = ""
                    has_error = has_error || has_temp_error
                    has_temp_error = false
                    mode = READ_ATTR
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
        elseif token != "CONTENT" && token != "COMMENT" && !occursin(r"SINGLE_", token)
            push(store_stack, token)
            has_error = true
        end
    end
    return !has_error && store_stack.size == 0
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
    temp, _ = convert_tojson_rec("WRAPPER", html, 0, READ_START)
    return temp
end

function convert_tojson_rec(tag::String, html::String, position::Int, mode::PARSE_MODE)::Tuple{HtmlJSON, Int}
    result = init_HtmlJSON(tag)
    store = ""
    store2 = ""
    counter = 0
    has_content = false
    has_temp_error = false
    has_exclamation = false
    is_singleton = occursin(singleton, tag)
    is_closed = false
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
            elseif occursin(whitespaces, string(c)) || (c == ' ' && store == "")
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
                    if !is_closed && store == "script"
                        mode = READ_SCRIPT
                    else
                        if !has_content
                            if occursin(singleton, store) || is_closed
                                push!(result.children, init_HtmlJSON(store))
                            else
                                temp, position = convert_tojson_rec(store, html, position, READ_TAG_CONTENT)
                                push!(result.children, temp)
                            end
                        else
                            if store != result.tag
                                throw(CloseTokenError(position))
                            end
                            return (result, position)
                        end
                        mode = READ_TAG_CONTENT
                    end
                    store = ""
                    has_temp_error = false
                    has_content = false
                    has_exclamation = false
                    is_closed = false
                elseif c == '/' && !has_content && !is_closed
                    if store == ""
                        has_content = true
                    elseif store != ""
                        is_closed = true
                    end
                elseif c == '!' && !has_content
                    has_exclamation = true
                elseif c == '-' && !has_content && has_exclamation
                    counter += 1
                    if counter == 2
                        has_exclamation = false
                        counter = 0
                        mode = READ_COMMENT
                    end
                elseif occursin(alphanum, string(c)) || (c == '!' && store == "")
                    store = string(store, lowercase(c))
                elseif c == ' ' && store != "" && !has_content
                    temp, position = convert_tojson_rec(store, html, position, READ_ATTR)
                    push!(result.children, temp)
                    has_content = false
                    store = ""
                    mode = READ_TAG_CONTENT
                else
                    throw(ParseError(position, mode))
                end
            elseif mode == READ_COMMENT
                if c == '-'
                    counter += 1
                    store2 = "--"
                elseif !occursin(whitespaces, string(c)) || store != ""
                    if c == '>' && counter >= 2
                        for _ in 1:counter-2
                            store = string(store, "-")
                        end
                        temp = init_HtmlJSON("comment")
                        push!(temp.children, store)
                        push!(result.children, temp)
                        store = ""
                        mode = READ_TAG_CONTENT
                    else
                        store = string(store, store2, c)
                    end
                    store2 = ""
                    counter = 0
                end
            elseif mode == READ_SCRIPT
                if c == '<'
                    store = string(store, store2)
                    store2 = "<"
                elseif c == '>'
                    if store2 == "</script"
                        is_script = false
                        if store != ""
                            temp = init_HtmlJSON("script")
                            push!(temp.children, store)
                            push!(result.children, temp)
                        end
                        mode = READ_TAG_CONTENT
                        store = ""
                    else
                        store = string(store, store2, c)
                        mode = READ_SCRIPT
                    end
                    store2 = ""
                elseif !occursin(whitespaces, string(c)) || store2 != ""
                    store2 = string(store2, c)
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
                elseif mode == READ_BOOLEAN
                    result.attributes[store] = store2 == "true"
                elseif mode == READ_ATTR && store != ""
                    result.attributes[store] = ""
                end
                if is_singleton
                    return (result, position)
                end
                if is_script
                    mode = READ_SCRIPT
                else
                    mode = READ_TAG_CONTENT
                end
                store = ""
                store2 = ""
                has_temp_error = false
                has_content = false
                has_exclamation = false
            elseif c == '/' && (mode != READ_STRING || has_content)
                is_closed = true
                is_singleton = true
            elseif mode == READ_ATTR
                if occursin(alphanum, string(c))
                    store = string(store, c)
                elseif c == '=' && store != ""
                    mode = READ_ATTR_CONTENT
                elseif c == ' '
                    if store != ""
                        result.attributes[store] = ""
                        store = ""
                    end
                else
                    throw(ParseError(position, mode))
                end
            elseif mode == READ_ATTR_CONTENT
                if occursin(alphabets, string(c))
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
                if c != ' '
                    store2 = string(store2, c)
                    has_temp_error = store2 != "false" && store2 != "true"
                else
                    if has_temp_error
                        throw(ParseError(position, mode))
                    end
                    result.attributes[store] = store2 == "true"
                    store = ""
                    store2 = ""
                    mode = READ_ATTR
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
                    else
                        has_temp_error = false
                    end
                    store2 = string(store2, c)
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
    if tag != "WRAPPER" || mode != READ_TAG_CONTENT || store != ""
        throw(ParseError(position, mode))
    end
    return (result, position)
end