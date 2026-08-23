# frozen_string_literal: true

module ArticlesHelper
  ARTICLE_TABLE_TAGS = %w[table thead tbody tfoot tr th td caption colgroup col].freeze

  def sanitize_article_content(content)
    allowed_tags = Rails::HTML5::SafeListSanitizer.allowed_tags.to_a + ARTICLE_TABLE_TAGS
    sanitize(content, tags: allowed_tags)
  end

  def preview_text(article, full)
    content = if article.text_coding == Article::CODING_HTML
                sanitize_article_content(article.text)
              else
                sanitize_article_content(article.text_parsed)
              end

    content = truncate(strip_tags(content), length: 200) unless full
    content
  end
end
