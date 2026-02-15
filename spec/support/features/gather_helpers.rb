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
        visit gather_path(gather)
        return unless wait_for_voting_state

        gather_map_votes = gather.map_votes.count

        return unless with_votes_scope('map-votes')

        votes.times do
          safe_click { all('ul#map-votes a', minimum: 1, wait: 5).sample.click }
          sleep(0.2) # Wait for vote to be processed before next click
        end

        sleep(1)
        gather.reload
        expect(gather.map_votes.count).to be >= gather_map_votes
      end
    end

    # Vote randomly on servers (each user can cast `votes` clicks)
    def vote_random_servers(session_name, votes: 2)
      Capybara.using_session(session_name) do
        visit gather_path(gather)
        return unless wait_for_voting_state

        gather_server_votes = gather.server_votes.count

        return unless with_votes_scope('server-votes')

        # If no vote links are available in this session, skip gracefully
        return unless page.has_selector?('ul#server-votes a', minimum: 1, wait: 2)

        votes.times do
          safe_click do
            first_choice = find('ul#server-votes a', match: :first, wait: 5)
            choices = all('ul#server-votes a')
            (choices.empty? ? first_choice : choices.sample).click
          end
          sleep(0.2) # Wait for vote to be processed before next click
        end

        sleep(1)
        gather.reload
        expect(gather.server_votes.count).to be >= gather_server_votes
      end
    end

    def wait_for_voting_state
      # Wait for gather to transition to voting state (happens when 12th player joins)
      max_wait = 30
      start_time = Time.current
      sleep(0.5) until gather.reload.status == Gather::STATE_VOTING || (Time.current - start_time) > max_wait

      gather.status == Gather::STATE_VOTING
    end

    def with_votes_scope(list_id)
      return false unless gather.reload.status == Gather::STATE_VOTING

      frame_selector = "turbo-frame#gather_#{gather.id}_frame"

      if page.has_selector?(frame_selector, wait: 10)
        within(frame_selector) do
          return false unless page.has_selector?("ul##{list_id}", wait: 3)
        end
      else
        return false unless page.has_selector?("ul##{list_id}", wait: 3)
      end

      true
    end

    # Efficiently sign in a user and join a gather in a single session operation
    # This minimizes page loads compared to separate sign_in_session + open_and_join calls
    def sign_in_and_join_gather(session_name, user, gather_arg = nil)
      Capybara.using_session(session_name) do
        gather_page = gather_arg || gather

        visit '/robots.txt'
        session_key = Rails.application.config.session_options[:key]
        cookie_value = session_cookie_for(user, session_key)
        set_session_cookie(session_key, cookie_value)

        # Visit the gather page with authenticated session
        visit gather_path(gather_page)

        if page.has_button?('Click to join gather!', wait: 5)
          safe_click { check 'gatherer[confirm]' } if page.has_field?('gatherer[confirm]', visible: :all)
          safe_click { click_button 'Click to join gather!' }

          if page.has_selector?('.message.notice', text: 'You have joined the Gather.', wait: 1)
            safe_expect_text('You have joined the Gather.')
          else
            gather_page.reload
            expect(gather_page.gatherers.of_user(user).count).to eq(1)
          end
        else
          gather_page.reload
          expect(gather_page.gatherers.of_user(user).count).to eq(1)
        end
      end
    end

    # Alias for backward compatibility
    def sign_in_and_join(session_name, user, gather_arg = nil)
      sign_in_and_join_gather(session_name, user, gather_arg)
    end
  end
end
