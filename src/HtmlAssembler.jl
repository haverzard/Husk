include("HtmlParser.jl")

function htmljson_serializer(json::HtmlJSON)::String
    html = string('<', json.tag)
    for (attr, content) in json.attributes
        html = string(html, " ", attr)
        type = typeof(content)
        if type == String
            if content != ""
                html = string(html, "=\"", content, '\"')
            end
        else
            html = string(html, '=', content)
        end
    end
    if length(json.children) == 0
        html = string(html, "/>")
    else
        html = string(html, '>')
        for child in json.children
            type = typeof(child)
            if type == HtmlJSON
                html = string(html, htmljson_serializer(child))
            elseif type == String
                html = string(html, child)
            end
        end
        html = string(html, "</", json.tag, '>')
    end
    return html
end