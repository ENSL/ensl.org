module Features
  module GatherHelpers
    # Sign in a user in a separate Capybara session.
    # Keeps the original signature used in specs: sign_in_session(session_name, user_index)
    def sign_in_session(session_name, user_index)
      Capybara.using_session(session_name) do
        sign_in_via_session(users[user_index])
      end
    end

    # Sign in a user object directly in a separate Capybara session
    def sign_in_session_user(session_name, user)
      Capybara.using_session(session_name) do
        sign_in_via_session(user)
      end
    end

    # Visit gather page and join. Assumes the user is logged in within this session.
    def open_and_join(session_name, user_index)
      Capybara.using_session(session_name) do
        visit gather_path(gather)

        expect(page).to have_content('Join')

        safe_click { check 'gatherer[confirm]' } if page.has_field?('gatherer[confirm]', visible: :all)
        safe_click { click_button 'Click to join gather!' }

        if page.has_selector?('.message.notice', text: 'You have joined the Gather.', wait: 1)
          safe_expect_text('You have joined the Gather.')
        else
          # Fallback for cases where the join flash does not render consistently
          # check via db
          gather.reload
          expect(gather.gatherers.of_user(users[user_index]).count).to eq(1)
        end
      end
    end

    # Vote randomly on maps (each user can cast `votes` clicks)
    def vote_random_maps(session_name, votes: 2)
      Capybara.using_session(session_name) do
        expect(page).to have_selector('ul#map-votes', wait: 10)
        gather_map_votes = gather.map_votes.count

        votes.times do
          safe_click { all('ul#map-votes a', minimum: 1, wait: 5).sample.click }
        end
        sleep(1)
        gather.reload
        expect(gather.map_votes.count).to be gather_map_votes + votes
      end
    end

    # Vote randomly on servers (each user can cast `votes` clicks)
    def vote_random_servers(session_name, votes: 2)
      Capybara.using_session(session_name) do
        expect(page).to have_selector('ul#server-votes', wait: 10)
        gather_server_votes = gather.server_votes.count

        votes.times do
          safe_click { all('ul#server-votes a', minimum: 1, wait: 3).sample.click }
        end

        sleep(1)
        gather.reload
        expect(gather.server_votes.count).to be gather_server_votes + votes
      end
    end

    # Efficiently sign in a user and join a gather in a single session operation
    # This minimizes page loads compared to separate sign_in_session + open_and_join calls
    def sign_in_and_join_gather(session_name, user, gather_arg = nil)
      Capybara.using_session(session_name) do
        gather_page = gather_arg || gather

        # Set session cookie with minimal page load
        visit '/'
        session_key = Rails.application.config.session_options[:key]
        cookie_value = session_cookie_for(user, session_key)
        set_session_cookie(session_key, cookie_value)

        # Visit the gather page with authenticated session
        visit gather_path(gather_page)

        expect(page).to have_content('Join')
        safe_click { check 'gatherer[confirm]' } if page.has_field?('gatherer[confirm]', visible: :all)
        safe_click { click_button 'Click to join gather!' }
        safe_expect_text('You have joined the Gather.')
      end
    end

    # Alias for backward compatibility
    def sign_in_and_join(session_name, user, gather_arg = nil)
      sign_in_and_join_gather(session_name, user, gather_arg)
    end
  end
end
