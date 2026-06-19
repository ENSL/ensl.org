# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IconHelper, type: :helper do
  describe '#fa_icon' do
    it 'renders a solid icon by default' do
      result = helper.fa_icon('camera')

      expect(result).to include('fa-solid')
      expect(result).to include('fa-camera')
    end

    it 'supports alternate icon styles' do
      result = helper.fa_icon('github', style: :brands)

      expect(result).to include('fa-brands')
      expect(result).to include('fa-github')
    end

    it 'supports the regular icon style' do
      result = helper.fa_icon('bell', style: :regular)

      expect(result).to include('fa-regular')
      expect(result).to include('fa-bell')
    end

    it 'falls back to solid for unknown styles' do
      result = helper.fa_icon('triangle-exclamation', style: :unknown)

      expect(result).to include('fa-solid')
      expect(result).to include('fa-triangle-exclamation')
    end

    it 'appends text when provided' do
      result = helper.fa_icon('user', text: 'Profile', class: 'extra')

      expect(result).to include('fa-solid')
      expect(result).to include('extra')
      expect(result).to include('Profile')
    end
  end
end
