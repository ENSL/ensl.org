BBCoder.configure do
  tag :i, as: :em
  tag :b, as: :strong

  tag :sub, singular: true do
    %(<sub>#{singular? ? meta : content}</sub>)
  end

  tag :sup, singular: true do
    %(<sup>#{singular? ? meta : content}</sup>)
  end

  tag :ul
  tag :ol
  tag :li, parents: [:ol, :ul]

  tag :size do
    %(<span style="font-size: #{meta}px;">#{content}</span>)
  end

  tag :url do
    if meta.nil? || meta.empty?
      %(<a href="#{content}">#{content}</a>)
    else
      %(<a href="#{meta}">#{content}</a>)
    end
  end

  tag :color do
    %(<span style="color: #{meta};">#{content}</span>)
  end
end
