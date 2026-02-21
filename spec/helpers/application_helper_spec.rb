# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#add_comments' do
    it 'returns empty safe string for nil object' do
      result = helper.add_comments(nil)

      expect(result).to eq('')
      expect(result).to be_html_safe
    end

    it 'returns empty safe string for non-commentable object' do
      result = helper.add_comments(Object.new)

      expect(result).to eq('')
      expect(result).to be_html_safe
    end
  end
end
