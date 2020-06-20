module Html

@enum PARSE_MODE READ_TAG READ_ATTR READ_ATTR_CONTENT READ_TAG_CONTENT

mutable struct TokenStack
    array
    size
end

function push(stack, value)
    push!(stack.array, value)
    stack.size += 1
end

struct HtmlJSON
    content
end

function tokenizer(html)
    stack = TokenStack(String[], 0)
    mode = READ_TAG_CONTENT
    store = ""
    for c in html;
        if mode == READ_TAG_CONTENT
            if c == '<'
                if store != ""
                    push(stack, store)
                end
                store = "<"
                mode = READ_TAG
            else
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

end