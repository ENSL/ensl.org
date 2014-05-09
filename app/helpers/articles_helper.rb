module ArticlesHelper
  def preview_text(article, full)
    if article.text_coding == Article::CODING_HTML
      content = article.text.html_safe
    else
      content = article.text_parsed.html_safe
    end 

    content = truncate(raw(strip_tags(content)), length: 200) if !full
    content
  end
end
