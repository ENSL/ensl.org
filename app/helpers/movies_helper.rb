# frozen_string_literal: true

module MoviesHelper
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
end
