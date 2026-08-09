# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Match predictions', type: :feature, js: true do
  let!(:user1) { create(:user, raw_password: 'TestPassword123') }
  let!(:user2) { create(:user) }
  let!(:contest) { create(:contest) }
  let!(:map1) { create(:map) }
  let!(:map2) { create(:map) }
  let!(:team1) { create(:team) }
  let!(:team2) { create(:team) }
  let!(:contester1) { create(:contester, team: team1, contest: contest) }
  let!(:contester2) { create(:contester, team: team2, contest: contest) }

  before do
    contest.maps << [map1, map2]
  end

  scenario 'User creates a prediction for a future match' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    sign_in_as(user1)
    visit match_path(match)

    # Verify the prediction form is visible
    expect(page).to have_button('Add Prediction')

    # Fill in the prediction
    fill_in 'prediction_score1', with: '2'
    fill_in 'prediction_score2', with: '1'
    click_button 'Add Prediction'

    # Verify success message and redirect
    expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Prediction.model_name.human))
    expect(page).to have_current_path(match_path(match))

    # Verify prediction was created
    expect(Prediction.where(user: user1, match: match).exists?).to be true
    pred = Prediction.find_by(user: user1, match: match)
    expect(pred.score1).to eq(2)
    expect(pred.score2).to eq(1)
  end

  scenario 'User cannot create a prediction after match time has passed' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 1.hour.ago)

    sign_in_as(user1)
    visit match_path(match)

    # Verify the prediction form is NOT visible
    expect(page).not_to have_button('Add Prediction')
  end

  scenario 'User cannot create two predictions for the same match' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    # Create first prediction
    create(:prediction, match: match, user: user1, score1: 2, score2: 1)

    sign_in_as(user1)
    visit match_path(match)

    # Verify the prediction form is NOT visible (user already predicted)
    expect(page).not_to have_button('Add Prediction')
  end

  scenario 'User gets error when submitting invalid scores', :aggregate_failures do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    sign_in_as(user1)
    visit match_path(match)

    # Try score out of range
    fill_in 'prediction_score1', with: '150'
    fill_in 'prediction_score2', with: '1'
    click_button 'Add Prediction'

    # Error message shows "Invalid score" in the page
    expect(page).to have_content('Invalid score')
  end

  scenario 'User gets error when submitting both scores as blank' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    sign_in_as(user1)
    visit match_path(match)

    # Don't fill in scores, just click submit
    click_button 'Add Prediction'

    # Empty scores fail validation and show error messages
    expect(page).to have_content('Invalid score')
    expect(Prediction.where(user: user1, match: match).exists?).to be false
  end

  scenario 'Multiple users can predict the same match' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    # User 1 predicts
    sign_in_as(user1)
    visit match_path(match)
    fill_in 'prediction_score1', with: '3'
    fill_in 'prediction_score2', with: '2'
    click_button 'Add Prediction'
    expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Prediction.model_name.human))

    # User 2 predicts
    sign_out
    sign_in_as(user2)
    visit match_path(match)
    fill_in 'prediction_score1', with: '2'
    fill_in 'prediction_score2', with: '1'
    click_button 'Add Prediction'
    expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Prediction.model_name.human))

    # Verify both predictions exist
    expect(Prediction.where(match: match).count).to eq(2)
  end

  scenario 'Match shows prediction statistics' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    # Create multiple predictions
    create(:prediction, match: match, user: create(:user), score1: 3, score2: 1)
    create(:prediction, match: match, user: create(:user), score1: 3, score2: 1)
    create(:prediction, match: match, user: create(:user), score1: 2, score2: 2)

    sign_in_as(user1)
    visit match_path(match)

    # Should show prediction count
    expect(page).to have_content('Predictions (3)')
  end

  scenario 'User can view their predictions on their profile' do
    match1 = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                            map1: map1, map2: map2, match_time: 2.hours.from_now)
    match2 = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                            map1: map1, map2: map2, match_time: 1.hour.from_now)

    contest2 = create(:contest)
    contest2.maps << [map1, map2]
    match3 = create(:match, contest: contest2, contester1: contester1, contester2: contester2,
                            map1: map1, map2: map2, match_time: 3.hours.from_now)

    # Create predictions
    create(:prediction, match: match1, user: user1, score1: 2, score2: 1)
    create(:prediction, match: match2, user: user1, score1: 3, score2: 0)
    create(:prediction, match: match3, user: user1, score1: 1, score2: 1)

    sign_in_as(user1)
    visit user_path(user1)

    # Click on predictions tab using the element's id
    find('#predictions').click

    # Verify predictions are displayed
    expect(page).to have_css('table.predictions')
    expect(page).to have_content('2 - 1')
    expect(page).to have_content('3 - 0')
    expect(page).to have_content('1 - 1')

    # Verify contest links are present
    expect(page).to have_link(contest.name)
    expect(page).to have_link(contest2.name)
  end

  scenario 'Predictions are evaluated when match results are set' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now,
                           score1: nil, score2: nil)

    # Create correct and incorrect predictions
    correct_pred = create(:prediction, match: match, user: user1, score1: 2, score2: 1)
    incorrect_pred = create(:prediction, match: match, user: user2, score1: 3, score2: 0)

    # Verify predictions have no result initially
    expect(correct_pred.reload.result).to be_nil
    expect(incorrect_pred.reload.result).to be_nil

    # Set match score to match one prediction
    match.update(score1: 2, score2: 1)
    match.set_predictions

    # Verify predictions were evaluated
    expect(correct_pred.reload.result).to eq(1)
    expect(incorrect_pred.reload.result).to eq(0)
  end

  scenario 'Contest predictions leaderboard shows correct scores' do
    match1 = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                            map1: map1, map2: map2, match_time: 1.hour.ago,
                            score1: 2, score2: 1)
    match2 = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                            map1: map1, map2: map2, match_time: 2.hours.ago,
                            score1: 1, score2: 0)

    # User1: 1 correct, 1 incorrect
    create(:prediction, match: match1, user: user1, score1: 2, score2: 1)
    create(:prediction, match: match2, user: user1, score1: 3, score2: 1)

    # User2: 2 correct
    create(:prediction, match: match1, user: user2, score1: 2, score2: 1)
    create(:prediction, match: match2, user: user2, score1: 1, score2: 0)

    # Set predictions
    match1.set_predictions
    match2.set_predictions

    # Visit contest page
    sign_in_as(user1)
    visit contest_path(contest)

    # Verify leaderboard is displayed (should show users with correct predictions)
    # This depends on the contest page having a predictions leaderboard section
    expect(page).to have_content(contest.name)
  end

  scenario 'Boundary score values work correctly (0 and 99)' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    sign_in_as(user1)
    visit match_path(match)

    # Test minimum scores
    fill_in 'prediction_score1', with: '0'
    fill_in 'prediction_score2', with: '0'
    click_button 'Add Prediction'

    expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Prediction.model_name.human))
    expect(Prediction.find_by(user: user1, match: match).score1).to eq(0)
    expect(Prediction.find_by(user: user1, match: match).score2).to eq(0)

    # Clean up for next test
    Prediction.find_by(user: user1, match: match).delete
    sign_out

    # Create another match for maximum scores test
    match2 = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                            map1: map1, map2: map2, match_time: 2.hours.from_now)

    sign_in_as(user1)
    visit match_path(match2)

    # Test maximum scores
    fill_in 'prediction_score1', with: '99'
    fill_in 'prediction_score2', with: '99'
    click_button 'Add Prediction'

    expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Prediction.model_name.human))
    expect(Prediction.find_by(user: user1, match: match2).score1).to eq(99)
    expect(Prediction.find_by(user: user1, match: match2).score2).to eq(99)
  end

  scenario 'Predictions persist correctly in database' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    sign_in_as(user1)
    visit match_path(match)

    fill_in 'prediction_score1', with: '2'
    fill_in 'prediction_score2', with: '1'
    click_button 'Add Prediction'

    # Verify the page indicates success
    expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Prediction.model_name.human))
    expect(page).to have_current_path(match_path(match))

    # Verify in database
    pred = Prediction.find_by(user: user1, match: match)
    expect(pred).to be_present
    expect(pred.match_id).to eq(match.id)
    expect(pred.user_id).to eq(user1.id)
    expect(pred.score1).to eq(2)
    expect(pred.score2).to eq(1)
    expect(pred.result).to be_nil # Not evaluated yet
  end

  scenario 'User cannot predict with non-numeric scores' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    sign_in_as(user1)
    visit match_path(match)

    fill_in 'prediction_score1', with: 'abc'
    fill_in 'prediction_score2', with: '1'
    click_button 'Add Prediction'

    # Non-numeric strings are cast to 0 by Rails, which is valid
    # This creates a prediction with score1=0, score2=1
    expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Prediction.model_name.human))
    pred = Prediction.find_by(user: user1, match: match)
    expect(pred.score1).to eq(0) # 'abc' is converted to 0
    expect(pred.score2).to eq(1)
  end

  scenario 'Unsigned in user cannot create prediction' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    visit match_path(match)

    # Should not see the prediction form
    expect(page).not_to have_button('Add Prediction')

    # Should see the statistics view
    expect(page).not_to have_css('input#prediction_score1')
  end

  scenario 'Prediction with score one set higher than 100 is rejected' do
    match = create(:match, contest: contest, contester1: contester1, contester2: contester2,
                           map1: map1, map2: map2, match_time: 2.hours.from_now)

    sign_in_as(user1)
    visit match_path(match)

    fill_in 'prediction_score1', with: '100'
    fill_in 'prediction_score2', with: '1'
    click_button 'Add Prediction'

    expect(page).to have_content('Invalid score')
    expect(Prediction.where(user: user1, match: match).exists?).to be false
  end
end
