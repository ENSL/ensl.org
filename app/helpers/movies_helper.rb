# frozen_string_literal: true

module MoviesHelper
  LOCAL_FILE_URL = %r{\A/files/(?!/)[^\r\n]*\z}

  def movie_rating_options
    [
      ['All', ''],
      ['5 stars', 5],
      ['4 stars', 4],
      ['3 stars', 3],
      ['2 stars', 2],
      ['1 star', 1]
    ]
  end

  def movie_download_url(movie_file)
    url = movie_file.url.to_s
    url if LOCAL_FILE_URL.match?(url)
  end
end
