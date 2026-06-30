# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Gather multi-user flow', type: :feature, js: true do
  # Create a gather with maps and servers, and 12 users
  let!(:gather) { FactoryBot.create(:gather, maps_count: 10, servers_count: 5) }
  let!(:users) { FactoryBot.create_list(:user, 12, raw_password: 'password123') }

  around do |example|
    previous_timeout = ENV['GATHER_VOTING_TIMEOUT_TEST']
    previous_skip_broadcasts = Gathers::Broadcaster.skip_broadcasts
    ENV['GATHER_VOTING_TIMEOUT_TEST'] = '20'
    Gathers::Broadcaster.skip_broadcasts = false
    example.run
  ensure
    Gathers::Broadcaster.skip_broadcasts = previous_skip_broadcasts
    ENV['GATHER_VOTING_TIMEOUT_TEST'] = previous_timeout
  end

  scenario '12 players join, vote on maps, pick teams, and finish the gather' do
    # Sign in and join with optimized helper (single efficient operation per user)
    users.each_with_index do |_, i|
      sign_in_and_join_gather("user_#{i}", users[i])
      print('.')
    end

    # Verify participant count
    gather.reload
    expect(gather.gatherers.count).to eq(12)

    # Start captain vote from one participant
    Capybara.using_session('user_0') do
      # With 12 concurrent sessions, this client can observe either the live
      # voting UI or the immediate transition to the picking phase.
      vote_phase_visible = safe_has_selector?('body', text: /Vote Captains/i, wait: 5)
      next if vote_phase_visible

      safe_expect_text('Captains are picking the teams', wait: 5)
    end

    # Track voting duration to ensure it lasts at least the configured timeout.
    # Use a monotonic clock to avoid issues with system time changes.
    voting_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    puts
    puts("All users joined the gather and voting has started. Timeout is: #{gather.voting_timeout} seconds.")

    vote_deadline = voting_deadline(buffer_seconds: 4)

    # Users vote while time remains; stop early before timeout to avoid racing state transition.
    users.each_with_index do |_, i|
      break unless voting_time_left?(vote_deadline, minimum_left: 1.0)

      vote_random_captains("user_#{i}", votes: 2, deadline: vote_deadline)
      vote_random_maps("user_#{i}", votes: 2, deadline: vote_deadline)
      vote_random_servers("user_#{i}", votes: 2, deadline: vote_deadline)
      print('.')
    end

    puts
    puts('Voting attempts completed (stopped early if close to timeout).')

    # Wait for voting phase to finish. In heavily concurrent headless runs,
    # background tab timers can lag, so do one explicit refresh fallback.
    Capybara.using_session('user_0') do
      picking_visible = safe_has_selector?(
        'body',
        text: /Captains are picking the teams/i,
        wait: gather.voting_timeout + 5
      )

      unless picking_visible
        visit_gather_with_retry(gather)
        safe_expect_text('Captains are picking the teams', wait: 8)
      end
    end

    voting_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - voting_start
    expect(voting_elapsed).to be >= (gather.voting_timeout - 5)

    # Find and verify captains are assigned in DB
    gather.reload
    captain1 = gather.captain1.user
    captain2 = gather.captain2.user
    expect(captain1).not_to be_nil
    expect(captain2).not_to be_nil

    # End-of-voting transition should create exactly one follow-up gather.
    expect(Gather.where(category_id: gather.category_id).count).to eq(2)

    expect(Gather.where(category_id: gather.category_id).count).to eq(2)

    # Verify that captains are the two most-voted users
    expect(gather.captain1.id).to eq(gather.gatherers.most_voted[1].id)
    expect(gather.captain2.id).to eq(gather.gatherers.most_voted[0].id)

    puts('Captain voting has ended, picking phase has started.')

    # Let whichever captain has the current turn pick from the lobby.
    remaining_picks = 9
    session_for_user_id = users.each_with_index.to_h { |u, i| [u.id, "user_#{i}"] }
    captain_sessions = [session_for_user_id[captain1.id], session_for_user_id[captain2.id]].compact

    remaining_picks.times do
      picked = false
      attempts = 0

      until picked || attempts >= 30
        attempts += 1
        gather.reload
        current_captain = gather.turn == 1 ? gather.captain1&.user : gather.captain2&.user
        session_name = session_for_user_id[current_captain.id]
        current_turn = gather.turn
        lobby_count = gather.gatherers.lobby.count
        candidate_sessions = ([session_name] + captain_sessions).uniq

        candidate_sessions.each do |candidate_session|
          Capybara.using_session(candidate_session) do
            turn_ready = safe_has_selector?(
              '#gather-stats',
              text: /It is your turn, please pick a player from the lobby!/i,
              wait: 2
            )

            unless turn_ready
              visit_gather_with_retry(gather)
              turn_ready = safe_has_selector?(
                '#gather-stats',
                text: /It is your turn, please pick a player from the lobby!/i,
                wait: 4
              )
            end

            next unless turn_ready

            visit_gather_with_retry(gather) unless safe_has_selector?('ul#lobby-gatherers input[type="radio"]', wait: 3)

            next unless safe_has_selector?('ul#lobby-gatherers input[type="radio"]', wait: 5)

            safe_click { all('ul#lobby-gatherers input[type="radio"]', minimum: 1, wait: 5).sample.click }
            safe_click { find('input[value="Pick"]').click }

            # Verify the pick actually happened by checking DB state changed
            sleep(0.3)
            gather.reload
            if gather.gatherers.lobby.count < lobby_count || gather.turn != current_turn
              picked = true
              print('.')
            end
          end

          break if picked
        end

        sleep(1) unless picked
      end

      raise 'No captain had a pickable player' unless picked

      sleep(rand(0.05..0.25))
    end

    puts
    puts('All players have been picked by the captains.')

    # Wait briefly for all updates to complete
    sleep(0.5)

    # Check in DB that both teams have 6 players
    gather.reload
    expect(gather.gatherers.team(1).count).to eq(6)
    expect(gather.gatherers.team(2).count).to eq(6)

    # Should say "Gather finished" after last pick to anyone
    Capybara.using_session('user_0') do
      safe_expect_text('Gather finished', wait: 5)
    end
  end
end
