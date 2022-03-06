module Jekyll
    class YearsCount < Liquid::Tag
        def render(context)
            "22"
        end
    end
end

Liquid::Template.register_tag('ycnt', Jekyll::YearsCount)
