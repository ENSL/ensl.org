# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.feature 'Movies management', type: :feature, js: true do
  include Features::VideoSampleHelper
  include MovieTestHelper

  let!(:admin) { create(:user, :admin) }
  let!(:movie_maker) { create(:user, :movie_maker) }
  let!(:regular_user) { create(:user) }

  let!(:movie_category) { create(:category, :movies, name: 'Frag Movies') }
  let!(:movies_directory) { setup_movies_directory }

  def open_movies_index
    visit movies_path
    expect(page).to have_content('Movie Archive')
  end

  describe 'browsing and filtering' do
    let!(:author_alpha) { create(:user, username: 'AlphaUser') }
    let!(:author_beta) { create(:user, username: 'BetaUser') }
    let!(:shorts_category) { create(:category, :movies, name: 'Shorts') }
    let!(:full_length_category) { create(:category, :movies, name: 'Full Length') }

    let!(:short_movie_high_rating) do
      create_movie_with_file(
        name: 'Short High',
        user: author_alpha,
        category: shorts_category,
        file_title: 'Short High',
        rating_score: 5
      ).tap { |m| create(:rating, rateable: m.file, rate: create(:rate, score: 5)) }
    end

    let!(:long_movie_medium_rating) do
      create_movie_with_file(
        name: 'Long Medium',
        user: author_beta,
        category: full_length_category,
        file_title: 'Long Medium',
        fixture_name: 'sample_mpeg4_mp3.avi',
        rating_score: 3
      ).tap { |m| create(:rating, rateable: m.file, rate: create(:rate, score: 3)) }
    end

    let!(:short_movie_low_rating) do
      create_movie_with_file(
        name: 'Short Low',
        user: author_alpha,
        category: shorts_category,
        file_title: 'Short Low',
        fixture_name: 'sample_h264_aac.mkv',
        rating_score: 2
      ).tap { |m| create(:rating, rateable: m.file, rate: create(:rate, score: 2)) }
    end

    let!(:long_movie_no_rating) do
      create_movie_with_file(
        name: 'Long No Rating',
        user: author_beta,
        category: full_length_category,
        file_title: 'Long No Rating',
        fixture_name: 'sample_vp9_opus.webm'
      )
    end

    scenario 'shows all movies without any filters' do
      open_movies_index

      expect(page).to have_css("a[href='#{movie_path(short_movie_high_rating)}']", visible: :all)
      expect(page).to have_css("a[href='#{movie_path(long_movie_medium_rating)}']", visible: :all)
      expect(page).to have_css("a[href='#{movie_path(short_movie_low_rating)}']", visible: :all)
      expect(page).to have_css("a[href='#{movie_path(long_movie_no_rating)}']", visible: :all)
    end

    scenario 'filters by author' do
      open_movies_index

      select 'AlphaUser', from: 'author'

      expect(page).to have_css("a[href='#{movie_path(short_movie_high_rating)}']", visible: :all)
      expect(page).to have_css("a[href='#{movie_path(short_movie_low_rating)}']", visible: :all)
      expect(page).not_to have_css("a[href='#{movie_path(long_movie_medium_rating)}']", visible: :all)
      expect(page).not_to have_css("a[href='#{movie_path(long_movie_no_rating)}']", visible: :all)
    end

    scenario 'filters by size - short movies' do
      open_movies_index

      click_link shorts_category.name

      expect(page).to have_css("a[href='#{movie_path(short_movie_high_rating)}']", visible: :all)
      expect(page).to have_css("a[href='#{movie_path(short_movie_low_rating)}']", visible: :all)
      expect(page).not_to have_css("a[href='#{movie_path(long_movie_medium_rating)}']", visible: :all)
      expect(page).not_to have_css("a[href='#{movie_path(long_movie_no_rating)}']", visible: :all)
    end

    scenario 'filters by size - long movies' do
      open_movies_index

      click_link full_length_category.name

      expect(page).to have_css("a[href='#{movie_path(long_movie_medium_rating)}']", visible: :all)
      expect(page).to have_css("a[href='#{movie_path(long_movie_no_rating)}']", visible: :all)
      expect(page).not_to have_css("a[href='#{movie_path(short_movie_high_rating)}']", visible: :all)
      expect(page).not_to have_css("a[href='#{movie_path(short_movie_low_rating)}']", visible: :all)
    end

    scenario 'filters by minimum rating' do
      open_movies_index

      select '3 stars', from: 'rating'

      expect(page).to have_css("a[href='#{movie_path(short_movie_high_rating)}']", visible: :all)
      expect(page).to have_css("a[href='#{movie_path(long_movie_medium_rating)}']", visible: :all)
      expect(page).not_to have_css("a[href='#{movie_path(short_movie_low_rating)}']", visible: :all)
    end

    scenario 'orders by date' do
      open_movies_index

      select 'Date', from: 'order'

      # Should still show all movies
      expect(page).to have_css("a[href='#{movie_path(short_movie_high_rating)}']", visible: :all)
    end

    scenario 'orders by author' do
      open_movies_index

      select 'Author', from: 'order'

      # Should still show all movies
      expect(page).to have_css("a[href='#{movie_path(short_movie_high_rating)}']", visible: :all)
    end

    scenario 'orders by ratings' do
      open_movies_index

      select 'Ratings', from: 'order'

      # Should still show all movies
      expect(page).to have_css("a[href='#{movie_path(short_movie_high_rating)}']", visible: :all)
    end

    scenario 'combines multiple filters' do
      open_movies_index

      select 'AlphaUser', from: 'author'
      expect(page).to have_select('author', selected: 'AlphaUser')

      click_link shorts_category.name
      expect(page).to have_link(shorts_category.name, class: /opacity-50/)

      select '3 stars', from: 'rating'
      expect(page).to have_select('rating', selected: '3 stars')

      expect(page).to have_css("a[href='#{movie_path(short_movie_high_rating)}']", visible: :all)
      expect(page).not_to have_css("a[href='#{movie_path(short_movie_low_rating)}']", visible: :all)
    end

    scenario 'verifies size filter categories are loaded dynamically from database' do
      open_movies_index

      # Verify both category buttons exist
      expect(page).to have_link(shorts_category.name)
      expect(page).to have_link(full_length_category.name)

      # Verify they match what's in the database
      db_categories = Category.movie_size_categories
      expect(db_categories).to include(shorts_category.name)
      expect(db_categories).to include(full_length_category.name)
    end
  end

  describe 'viewing movies' do
    scenario 'user can navigate from index to movie show page and watch preview player' do
      preview_file = make_movie_file(title: 'Preview Showcase', fixture_name: 'sample_h264_aac.mkv')
      movie = create_movie_with_file(
        name: 'Showcase Movie',
        user: admin,
        category: movie_category,
        file_title: 'Showcase Movie'
      )
      movie.update(preview: preview_file)

      open_movies_index
      click_link 'Showcase Movie'

      expect(page).to have_content('Showcase Movie')
      expect(page).to have_css('video')
      expect(page).to have_link(File.basename(movie.file.name.to_s))
    end
  end

  describe 'navigation and creation' do
    scenario 'admin can navigate from index to new data file and upload' do
      src = test_video_path('sample_h264_aac.mp4')
      description = "Uploaded through UI form #{SecureRandom.hex(4)}"

      sign_in_as(admin)
      visit movies_path

      click_link 'here'

      attach_file 'data_file_name', src.to_s
      fill_in 'data_file_title', with: description
      find("#data_file_directory_id option[value='#{Directory::MOVIES}']").select_option

      click_button 'Create File'

      expect(page).to have_content(I18n.t(:files_create))

      uploaded = DataFile.find_by(title: description)
      expect(uploaded).to be_present
      expect(uploaded.location).to be_present
      expect(File.exist?(uploaded.location)).to be true
      expect(uploaded.movie).to be_present
      expect(page).to have_current_path(movie_path(uploaded.movie), ignore_query: true)
      expect(page).to have_content(description)
    end

    scenario 'movie maker can navigate from index to new data file and upload' do
      src = test_video_path('sample_h264_aac.mp4')
      description = "Uploaded by movie maker #{SecureRandom.hex(4)}"

      sign_in_as(movie_maker)
      visit movies_path

      click_link 'here'

      attach_file 'data_file_name', src.to_s
      fill_in 'data_file_title', with: description
      find("#data_file_directory_id option[value='#{Directory::MOVIES}']").select_option

      click_button 'Create File'

      expect(page).to have_content(I18n.t(:files_create))

      uploaded = DataFile.find_by(title: description)
      expect(uploaded).to be_present
      expect(uploaded.location).to be_present
      expect(File.exist?(uploaded.location)).to be true
      expect(uploaded.movie).to be_present
      expect(page).to have_current_path(movie_path(uploaded.movie), ignore_query: true)
    end

    scenario 'admin can create movie through new movie form' do
      file = make_movie_file(title: 'Create Source', fixture_name: 'sample_h264_aac.mp4')

      sign_in_as(admin)
      visit new_movie_path

      expect(page).to have_content('New Movie')

      fill_in 'movie_name', with: 'My Created Movie'
      select movie_category.name, from: 'movie_category_id'
      fill_in 'movie_content', with: 'Created in feature spec'
      fill_in 'movie_format', with: 'h264'
      fill_in 'movie_length', with: '420'
      selected_label = File.basename(file.name.to_s)
      select selected_label, from: 'movie_file_id'

      click_button 'Save'

      expect(page).to have_content(I18n.t(:movies_create))
      expect(page).to have_content('Created in feature spec')
      created = Movie.find_by(content: 'Created in feature spec')
      expect(created).to be_present
      expect(created.user_id).to eq(admin.id)
      expect(created.file_id).to eq(file.id)
    end

    scenario 'movie maker can create movie through ui' do
      file = make_movie_file(title: 'Maker Source', fixture_name: 'sample_vp9_opus.webm')

      sign_in_as(movie_maker)
      visit new_movie_path

      fill_in 'movie_name', with: 'Maker Created Movie'
      select movie_category.name, from: 'movie_category_id'
      select File.basename(file.name.to_s), from: 'movie_file_id'

      click_button 'Save'

      expect(page).to have_content(I18n.t(:movies_create))
      expect(Movie.where(user_id: movie_maker.id).count).to be >= 1
    end
  end

  describe 'admin functions' do
    scenario 'admin can open movies admin index' do
      create_movie_with_file(
        name: 'Admin Panel Movie',
        user: admin,
        category: movie_category,
        fixture_name: 'sample_h264_aac.mkv'
      )

      sign_in_as(admin)
      visit admin_movies_path

      expect(page).to have_content('Movies Admin')
      expect(page).to have_content('Admin Panel Movie')
    end

    scenario 'regular user is blocked from movies admin index' do
      sign_in_as(regular_user)
      visit admin_movies_path

      expect(page.status_code).to eq(403)
    end

    scenario 'movie maker is blocked from movies admin index' do
      sign_in_as(movie_maker)
      visit admin_movies_path

      expect(page.status_code).to eq(403)
    end

    scenario 'admin can edit any movie' do
      movie = create_movie_with_file(
        name: 'Original Title',
        user: movie_maker,
        category: movie_category,
        content: 'Old content',
        fixture_name: 'sample_h264_aac.mp4'
      )

      sign_in_as(admin)
      visit edit_movie_path(movie)

      fill_in 'movie_name', with: 'Updated Title'
      fill_in 'movie_content', with: 'Updated content'

      click_button 'Save'

      expect(page).to have_content(I18n.t(:movies_update))
      expect(page).to have_content('Updated content')
      expect(movie.reload.content).to eq('Updated content')
    end

    scenario 'admin can destroy any movie from show controls', js: false do
      movie = create_movie_with_file(
        name: 'Destroy Me',
        user: movie_maker,
        category: movie_category,
        fixture_name: 'sample_h264_aac.mp4'
      )

      sign_in_as(admin)
      visit movie_path(movie)

      expect(page).to have_button('Destroy')
      click_button 'Destroy'
      visit movies_path

      expect(Movie.find_by(id: movie.id)).to be_nil
      expect(page).to have_content('Movie Archive')
    end
  end

  describe 'movie maker ownership permissions' do
    scenario 'movie maker can edit their own movie' do
      movie = create_movie_with_file(
        name: 'Maker Own Movie',
        user: movie_maker,
        category: movie_category,
        content: 'Original maker content',
        fixture_name: 'sample_h264_aac.mp4'
      )

      sign_in_as(movie_maker)
      visit movie_path(movie)

      expect(page).to have_link('Edit')
      click_link 'Edit'

      fill_in 'movie_content', with: 'Updated by maker'
      click_button 'Save'

      expect(page).to have_content(I18n.t(:movies_update))
      expect(page).to have_content('Updated by maker')
      expect(movie.reload.content).to eq('Updated by maker')
    end

    scenario 'movie maker can destroy their own movie', js: false do
      skip
      movie = create_movie_with_file(
        name: 'Maker Destroy Own',
        user: movie_maker,
        category: movie_category,
        fixture_name: 'sample_h264_aac.mp4'
      )

      sign_in_as(movie_maker)
      visit movie_path(movie)

      expect(page).to have_button('Destroy')
      click_button 'Destroy'
      visit movies_path

      expect(Movie.find_by(id: movie.id)).to be_nil
    end

    scenario 'movie maker cannot edit movies by other users' do
      other_user = create(:user)
      movie = create_movie_with_file(
        name: 'Other User Movie',
        user: other_user,
        category: movie_category,
        fixture_name: 'sample_h264_aac.mp4'
      )

      sign_in_as(movie_maker)
      visit movie_path(movie)

      expect(page).not_to have_link('Edit')
    end

    scenario 'movie maker cannot destroy movies by other users' do
      other_user = create(:user)
      movie = create_movie_with_file(
        name: 'Other User Movie Destroy',
        user: other_user,
        category: movie_category,
        fixture_name: 'sample_h264_aac.mp4'
      )

      sign_in_as(movie_maker)
      visit movie_path(movie)

      # Should not see edit controls at all since they don't own the movie
      expect(page).not_to have_link('Edit')
      within('table.movie') do
        expect(page).not_to have_link('Destroy', exact: true)
      end
    end

    scenario 'movie maker can make preview for their own movie' do
      movie = create_movie_with_file(
        name: 'Maker Preview Movie',
        user: movie_maker,
        category: movie_category,
        web_friendly: false,
        fixture_name: 'sample_h264_aac.mp4'
      )

      sign_in_as(movie_maker)
      visit edit_movie_path(movie)

      click_button 'Make a Preview'

      Timeout.timeout(20) do
        loop do
          break if movie.reload.preview_url.present?

          sleep 0.1
        end
      end
      expect(movie.reload.preview_url).to be_present
    end

    scenario 'movie maker can take snapshot for their own movie' do
      movie = create_movie_with_file(
        name: 'Maker Snapshot Movie',
        user: movie_maker,
        category: movie_category,
        fixture_name: 'sample_h264_aac.mp4'
      )

      FileUtils.rm_f(movie.snapshot_path)

      sign_in_as(movie_maker)
      visit edit_movie_path(movie)

      fill_in 'secs', with: '5'
      click_button 'Take Snapshot'

      expect(page).to have_content('Snapshot created.')
      expect(File.exist?(movie.reload.snapshot_path)).to be true
    end

    scenario 'movie maker sees error when snapshot cannot be created' do
      movie = create_movie_with_file(
        name: 'Maker Snapshot Missing Source',
        user: movie_maker,
        category: movie_category,
        fixture_name: 'sample_h264_aac.mp4'
      )

      FileUtils.rm_f(movie.file.location)
      FileUtils.rm_f(movie.snapshot_path)

      sign_in_as(movie_maker)
      visit edit_movie_path(movie)

      fill_in 'secs', with: '5'
      click_button 'Take Snapshot'

      expect(page).to have_content('Snapshot could not be created.')
      expect(File.exist?(movie.reload.snapshot_path)).to be false
    end
  end

  describe 'regular user permissions' do
    scenario 'regular user cannot edit or destroy another user movie' do
      movie = create_movie_with_file(
        name: 'Protected Movie',
        user: admin,
        category: movie_category,
        fixture_name: 'sample_h264_aac.mp4'
      )

      sign_in_as(regular_user)
      visit movie_path(movie)

      expect(page).not_to have_link('Edit')
      expect(page).not_to have_link('Destroy')
    end

    scenario 'regular user cannot access new movie form' do
      sign_in_as(regular_user)

      visit new_movie_path

      expect(page.status_code).to eq(403)
      expect(page).to have_content(I18n.t(:user_registration_required))
    end
  end

  describe 'preview variants' do
    scenario 'movie with web_friendly uploaded preview shows preview player' do
      # Create main file
      file = make_movie_file(title: 'Web Friendly Movie', fixture_name: 'sample_h264_aac.mp4')
      # Create preview file separately since it uses different fixture
      preview = make_movie_file(title: 'Web Friendly Preview', fixture_name: 'sample_h264_aac.mkv')
      movie = create(:movie,
                     name: 'Web Friendly Movie',
                     user: admin,
                     file: file,
                     preview: preview,
                     category: movie_category,
                     web_friendly: true)

      sign_in_as(regular_user)
      visit movie_path(movie)

      expect(page).to have_content('Web Friendly Movie')
      expect(page).to have_css('video')
      # Preview exists, but player prefers original when it is web-friendly
      expect(movie.preview).to be_present
      expect(movie.preview_url).to be_present
      expect(movie.original_url).to be_present
      expect(page).to have_css("video source[src='#{movie.original_url}']", visible: false)
    end

    scenario 'movie with rails-made preview (not web_friendly initially) shows preview after generation' do
      movie = create_movie_with_file(
        name: 'Rails Preview Movie',
        user: admin,
        category: movie_category,
        web_friendly: false,
        fixture_name: 'sample_h264_aac.mp4'
      )

      expect(movie.preview).to be_nil

      sign_in_as(admin)
      visit edit_movie_path(movie)

      click_button 'Make a Preview'

      Timeout.timeout(20) do
        loop do
          break if movie.reload.preview_url.present?

          sleep 0.1
        end
      end
      expect(movie.reload.preview_url).to be_present

      # Now visit show page and verify preview is available
      visit movie_path(movie)
      expect(page).to have_css('video')
    end

    scenario 'movie without preview still displays properly' do
      movie = create_movie_with_file(
        name: 'No Preview Movie',
        user: admin,
        category: movie_category,
        web_friendly: true,
        fixture_name: 'sample_h264_aac.mp4'
      )

      expect(movie.preview).to be_nil

      visit movie_path(movie)

      expect(page).to have_content('No Preview Movie')
      # Should still show download link
      expect(page).to have_link(File.basename(movie.file.name.to_s))
    end
  end
end
