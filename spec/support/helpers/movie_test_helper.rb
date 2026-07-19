# frozen_string_literal: true

module MovieTestHelper
  def setup_movies_directory
    root = Directory.find_or_create_by(id: Directory::ROOT) do |r|
      r.name = 'root'
      r.title = 'Root'
    end
    Directory.find_or_create_by(id: Directory::MOVIES) do |d|
      d.name = 'movies'
      d.title = 'Movies'
      d.parent = root
    end
  end

  def make_movie_file(title: 'Movie File', fixture_name: 'sample_h264_aac.mp4')
    movies_dir = setup_movies_directory
    src = test_video_path(fixture_name)
    build(:data_file, directory: movies_dir, title: title, skip_file_validation: true).tap do |file|
      File.open(src, 'rb') { |uploaded| file.name = uploaded }
      file.save!
      file.reload
    end
  end

  def create_movie_with_file(attributes = {})
    fixture_name = attributes.delete(:fixture_name) || 'sample_h264_aac.mp4'
    file_title = attributes.delete(:file_title) ||
                 attributes.delete(:file_description) ||
                 attributes[:name] ||
                 'Movie File'

    # Extract rating_score if present (transient attribute for :with_rating trait)
    rating_score = attributes.delete(:rating_score)

    file = make_movie_file(title: file_title, fixture_name: fixture_name)
    attributes[:file] = file

    # If rating_score was specified, pass it through the trait mechanism
    if rating_score
      create(:movie, :with_rating, **attributes, rating_score: rating_score)
    else
      create(:movie, attributes)
    end
  end
end
