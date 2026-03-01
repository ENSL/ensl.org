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
        visit_gather_with_retry(gather)

        expect(page).to have_content('Join')

        safe_click { check 'gatherer[confirm]' } if page.has_field?('gatherer[confirm]', visible: :all)
        safe_click { click_button 'Click to join gather!' }

        # Wait for 'Leave Gather' — only appears once the join response is applied
        page.has_button?('Leave Gather', wait: Capybara.default_max_wait_time)
        gather.reload
        expect(gather.gatherers.of_user(users[user_index]).count).to eq(1)
      end
    end

    # Vote randomly on captains (gatherers) while voting is still open.
    def vote_random_captains(session_name, votes: 2, deadline: nil)
      return unless voting_time_left?(deadline)

      Capybara.using_session(session_name) do
        return unless voting_time_left?(deadline)

        # No page re-visit: after joining, every session already has the gather
        # page open. gather_sync_controller.js polls for version changes and
        # reloads the frame automatically when the gather transitions to VOTING.
        return unless wait_for_voting_state(deadline: deadline)
        return unless voting_time_left?(deadline)

        gatherer_votes = gather.gatherer_votes.count
        attempted_captain_vote_urls = []

        return unless with_votes_scope('gatherers')
        return unless page.has_selector?('table#gatherers a.vote-link', minimum: 1, wait: 1)

        votes.times do
          break unless voting_time_left?(deadline, minimum_left: 0.3)
          break unless page.has_selector?('table#gatherers a.vote-link', minimum: 1, wait: 1)

          available_choices = all('table#gatherers a.vote-link').reject do |choice|
            attempted_captain_vote_urls.include?(choice[:href])
          end
          break if available_choices.empty?

          safe_click do
            choices = all('table#gatherers a.vote-link').reject do |choice|
              attempted_captain_vote_urls.include?(choice[:href])
            end
            raise Capybara::ElementNotFound if choices.empty?

            choice = choices.sample
            attempted_captain_vote_urls << choice[:href]
            choice.click
          end

          sleep(0.15)
        end

        gather.reload
        expect(gather.gatherer_votes.count).to be >= gatherer_votes
      end
    end

    # Vote randomly on maps (each user can cast `votes` clicks)
    def vote_random_maps(session_name, votes: 2, deadline: nil)
      return unless voting_time_left?(deadline)

      Capybara.using_session(session_name) do
        return unless voting_time_left?(deadline)

        return unless wait_for_voting_state(deadline: deadline)
        return unless voting_time_left?(deadline)

        gather_map_votes = gather.map_votes.count

        return unless with_votes_scope('map-votes')

        # If no vote links are available in this session, skip gracefully
        return unless page.has_selector?('ul#map-votes a.vote-link', minimum: 1, wait: 1)

        votes.times do
          break unless voting_time_left?(deadline, minimum_left: 0.3)

          # Vote links can legitimately disappear once user reached vote limit
          break unless page.has_selector?('ul#map-votes a.vote-link', minimum: 1, wait: 1)

          safe_click do
            first_choice = find('ul#map-votes a.vote-link', match: :first, wait: 2)
            choices = all('ul#map-votes a.vote-link')
            (choices.empty? ? first_choice : choices.sample).click
          end
          sleep(0.15)
        end

        gather.reload
        expect(gather.map_votes.count).to be >= gather_map_votes
      end
    end

    # Vote randomly on servers (each user can cast `votes` clicks)
    def vote_random_servers(session_name, votes: 2, deadline: nil)
      return unless voting_time_left?(deadline)

      Capybara.using_session(session_name) do
        return unless voting_time_left?(deadline)

        return unless wait_for_voting_state(deadline: deadline)
        return unless voting_time_left?(deadline)

        gather_server_votes = gather.server_votes.count

        return unless with_votes_scope('server-votes')

        # If no vote links are available in this session, skip gracefully
        return unless page.has_selector?('ul#server-votes a', minimum: 1, wait: 1)

        votes.times do
          break unless voting_time_left?(deadline, minimum_left: 0.3)
          break unless page.has_selector?('ul#server-votes a', minimum: 1, wait: 1)

          safe_click do
            first_choice = find('ul#server-votes a', match: :first, wait: 2)
            choices = all('ul#server-votes a')
            (choices.empty? ? first_choice : choices.sample).click
          end
          sleep(0.15)
        end

        gather.reload
        expect(gather.server_votes.count).to be >= gather_server_votes
      end
    end

    def voting_deadline(buffer_seconds: 4)
      Process.clock_gettime(Process::CLOCK_MONOTONIC) + [gather.voting_timeout.to_f - buffer_seconds, 1.0].max
    end

    def wait_for_voting_state(deadline: nil)
      # Wait for gather to transition to voting state (happens when 12th player joins)
      max_wait = 30
      start_time = Time.current

      until gather.reload.status == Gather::STATE_VOTING || (Time.current - start_time) > max_wait
        return false unless voting_time_left?(deadline, minimum_left: 0.2)

        sleep(0.5)
      end

      gather.status == Gather::STATE_VOTING
    end

    def voting_time_left?(deadline, minimum_left: 0.8)
      return true if deadline.nil?

      (deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)) > minimum_left
    end

    def with_votes_scope(list_id)
      return false unless gather.reload.status == Gather::STATE_VOTING

      frame_selector = "turbo-frame#gather_#{gather.id}_frame"

      # After removing page re-visits from vote helpers we must allow enough
      # time for gather_sync_controller.js to poll (/version every 5 s in test)
      # and reload the frame before we check for vote links.
      wait_for_content = 10

      if page.has_selector?(frame_selector, wait: wait_for_content)
        within(frame_selector) do
          return false unless page.has_selector?("ul##{list_id}", wait: wait_for_content)
        end
      else
        return false unless page.has_selector?("ul##{list_id}", wait: wait_for_content)
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
        visit_gather_with_retry(gather_page)

        if page.has_button?('Click to join gather!', wait: 5)
          safe_click { check 'gatherer[confirm]' } if page.has_field?('gatherer[confirm]', visible: :all)
          safe_click { click_button 'Click to join gather!' }

          # Wait for the turbo-stream response to be applied. Turbo disables the
          # submit button immediately on click (to prevent double-submit), which
          # fools has_no_button? into returning true before the server responds.
          # 'Leave Gather' only appears after a successful join AND the frame is
          # replaced — reliable proof the INSERT is committed and DOM is updated.
          page.has_button?('Leave Gather', wait: Capybara.default_max_wait_time)
          gather_page.reload
          expect(gather_page.gatherers.of_user(user).count).to eq(1)
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

    private

    # Simple navigation – rely on Capybara's built-in visit rather than
    # bypassing it with raw Playwright goto. Capybara handles driver
    # differences and its default wait-until is appropriate for the test
    # Puma server we configure.
    def visit_gather_with_retry(gather_page)
      visit gather_path(gather_page)
    end
  end
end
