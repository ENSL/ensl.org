# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoviesHelper, type: :helper do
  describe '#movie_rating_options' do
    it 'returns the expected movie rating select options' do
      expect(helper.movie_rating_options).to eq(
        [
          ['All', ''],
          ['5 stars', 5],
          ['4 stars', 4],
          ['3 stars', 3],
          ['2 stars', 2],
          ['1 star', 1]
        ]
      )
    end
  end
end
