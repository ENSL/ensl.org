require 'rails_helper'

RSpec.describe ArticlesHelper, type: :helper do
  describe '#preview_text' do
    it 'sanitizes html content and truncates it when full is false' do
      article = instance_double(Article, text_coding: Article::CODING_HTML, text: '<b>Hello</b>',
                                         text_parsed: 'ignored')

      expect(helper.preview_text(article, false)).to eq('Hello')
    end

    it 'uses parsed text and skips truncation when full is true' do
      article = instance_double(Article, text_coding: Article::CODING_BBCODE, text: 'ignored',
                                         text_parsed: '<i>Parsed</i>')

      expect(helper.preview_text(article, true)).to eq('<i>Parsed</i>')
    end
  end
end
