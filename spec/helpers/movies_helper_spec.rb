# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoviesHelper, type: :helper do
  describe '#movie_download_url' do
    it 'returns local file URLs' do
      movie_file = instance_double(DataFile, url: '/files/movies/video.mp4')

      expect(helper.movie_download_url(movie_file)).to eq('/files/movies/video.mp4')
    end

    it 'rejects non-local and malformed URLs' do
      expect(helper.movie_download_url(instance_double(DataFile, url: 'javascript:alert(1)'))).to be_nil
      expect(helper.movie_download_url(instance_double(DataFile, url: '//example.test/file.mp4'))).to be_nil
      malformed_file = instance_double(DataFile, url: "/files/video.mp4\njavascript:alert(1)")

      expect(helper.movie_download_url(malformed_file)).to be_nil
    end
  end

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
