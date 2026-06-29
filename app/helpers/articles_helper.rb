# frozen_string_literal: true

module ArticlesHelper
  def preview_text(article, full)
    content = if article.text_coding == Article::CODING_HTML
                sanitize(article.text)
              else
                sanitize(article.text_parsed)
              end

    content = truncate(strip_tags(content), length: 200) unless full
    content
  end
end
