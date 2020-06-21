module Html

@enum PARSE_MODE READ_TAG READ_ATTR READ_ATTR_CONTENT READ_CLOSE_TAG READ_STRING READ_NUM READ_BOOLEAN READ_TAG_CONTENT

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
        if mode == READ_TAG_CONTENT
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
                if store != "TOKEN_" && !has_error && !has_temp_error
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
                elseif c == ' ' && store != "TOKEN_" && has_content
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
                if occursin(alphanum, string(c))
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
                    if store2 == "false" || store2 == "true"
                        has_temp_error = false
                    end
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
                    mode = READ_ATTR
                elseif c == '\\'
                    has_temp_error = !has_temp_error
                elseif occursin(r"abfnrtv", string(c)) && has_temp_error
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
    content
end

end