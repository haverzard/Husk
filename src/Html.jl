module Html

@enum PARSE_MODE READ_TAG READ_ATTR READ_ATTR_CONTENT READ_CLOSE_TAG READ_TAG_CONTENT

mutable struct TokenStack
    array::Array{String,1}
    size::UInt
end

function push(stack::TokenStack, value::String)
    push!(stack.array, value)
    stack.size += 1
end

function pop(stack::TokenStack)::String
    return pop!(stack.array)
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
    re = r"[0-9a-zA-Z]"
    has_content = false
    has_error = false
    for c in html
        if mode == READ_TAG_CONTENT
            if c == '<'
                if has_content
                    push(stack, "STRING")
                end
                store = "TOKEN_"
                has_content = false
                mode = READ_TAG
            else
                has_content = true
            end
        elseif mode == READ_TAG
            if c == '>'
                if store != "TOKEN_"
                    push(stack, store)
                else
                    push(stack, "BAD_TOKEN")
                end
                store = ""
                has_content = false
                mode = READ_TAG_CONTENT
            elseif c == '/' && store == "TOKEN_"
                store = string(store, "END_")
                has_content = true
            elseif occursin(re, string(c))
                store = string(store, uppercase(c))
            else
                if has_content
                    has_error = true
                end
                mode = READ_CLOSE_TAG
            end
        elseif mode == READ_CLOSE_TAG
            if c == '>'
                if store != "TOKEN_" && !has_error
                    push(stack, store)
                else
                    push(stack, "BAD_TOKEN")
                end
                store = ""
                has_error = false
                has_content = false
                mode = READ_TAG_CONTENT
            else
                # Ignore
            end
        end
    end
    if has_content
        push(stack, "STRING")
    end
    return stack
end

function check(stack::TokenStack)::Bool
    store_stack = TokenStack(String[], 0)
    for token in stack.array
        
    end
end

struct HtmlJSON
    content
end

end