# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomUrl, type: :model do
  let(:article) { create(:article) }

  describe 'name normalization' do
    it 'normalizes whitespace and casing before validation' do
      custom_url = described_class.create!(name: '  Mixed CASE ', article: article)

      expect(custom_url.name).to eq('mixed-case')
    end
  end

  describe 'menu-linked protection' do
    it 'blocks deleting menu-linked custom urls' do
      custom_url = described_class.create!(name: 'rules', article: article)

      expect(custom_url.destroy).to be(false)
      expect(custom_url.errors.full_messages).to include(I18n.t('custom_urls.destroy.menu_linked', name: 'rules'))
      expect(described_class.exists?(custom_url.id)).to be(true)
    end
  end
end
