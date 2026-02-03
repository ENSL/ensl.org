module Features
  module GatherHelpers
    # Sign in a user in a separate Capybara session.
    # Keeps the original signature used in specs: sign_in_session(session_name, user_index)
    def sign_in_session(session_name, user_index)
      Capybara.using_session(session_name) do
        sign_in_via_session(users[user_index])
      end
    end

    # Visit gather page and join. Assumes the user is logged in within this session.
    def open_and_join(session_name, user_index)
      Capybara.using_session(session_name) do
        visit gather_path(gather)

        expect(page).to have_content('Join')

        safe_click { check 'gatherer[confirm]' } if page.has_field?('gatherer[confirm]', visible: :all)
        safe_click { click_button 'Click to join gather!' }

        safe_expect_text('You have joined the Gather.')
      end
    end

    # Vote randomly on maps (each user can cast `votes` clicks)
    def vote_random_maps(session_name, votes: 2)
      Capybara.using_session(session_name) do
        attempts = 0
        until page.has_selector?('ul#map-votes', wait: 2) || attempts >= 10
          attempts += 1
          visit gather_path(gather)
          sleep(0.5)
        end

        return unless page.has_selector?('ul#map-votes', wait: 1)

        votes.times do
          tries = 0
          begin
            tries += 1
            safe_click { find('ul#map-votes', wait: 10).all('a').sample.click }
          rescue Capybara::ElementNotFound, Net::ReadTimeout
            return if tries >= 5

            visit gather_path(gather)
            sleep(0.5)
            retry
          end
          sleep(rand(0.05..0.25))
        end
      end
    end

    # Vote randomly on servers (each user can cast `votes` clicks)
    def vote_random_servers(session_name, votes: 2)
      Capybara.using_session(session_name) do
        attempts = 0
        until page.has_selector?('ul#server-votes', wait: 2) || attempts >= 10
          attempts += 1
          visit gather_path(gather)
          sleep(0.5)
        end

        return unless page.has_selector?('ul#server-votes', wait: 1)

        votes.times do
          tries = 0
          begin
            tries += 1
            safe_click { find('ul#server-votes', wait: 10).all('a').sample.click }
          rescue Capybara::ElementNotFound, Net::ReadTimeout
            return if tries >= 5

            visit gather_path(gather)
            sleep(0.5)
            retry
          end
          sleep(rand(0.05..0.25))
        end
      end
    end

    # Sign in using a specific user object in a separate Capybara session.
    def sign_in_session_user(session_name, user)
      Capybara.using_session(session_name) do
        sign_in_via_session(user)
      end
    end

    # Sign in a user and join the gather in a single helper.
    # If gather_arg is provided it will visit that gather, otherwise uses local `gather`.
    def sign_in_and_join(session_name, user, gather_arg = nil)
      Capybara.using_session(session_name) do
        sign_in_via_session(user)
        visit gather_path(gather_arg || gather)
        expect(page).to have_content('Join')
        safe_click { check 'gatherer[confirm]' } if page.has_field?('gatherer[confirm]', visible: :all)
        safe_click { click_button 'Click to join gather!' }
        safe_expect_text('You have joined the Gather.')
      end
    end
  end
end

RSpec.configure do |c|
  c.include Features::GatherHelpers, type: :feature
  c.include Features::GatherHelpers, type: :system
end
