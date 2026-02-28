require 'rails_helper'

RSpec.describe 'Gathers version endpoint', type: :request do
  let(:user) { create(:user) }
  let(:gather) { create(:gather) }

  def login_as(u)
    post '/users/login', params: { login: { username: u.username, password: u.raw_password } }
    follow_redirect! if response.redirect?
  end

  it 'updates user lastvisit on GET /gathers/:id/version' do
    login_as(user)
    stale_lastvisit = 3.hours.ago.change(usec: 0)
    user.update_columns(lastvisit: stale_lastvisit)

    get version_gather_path(gather), headers: { 'ACCEPT' => 'application/json' }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include('id' => gather.id)
    expect(user.reload.lastvisit).to be > stale_lastvisit
  end

  it 'updates user lastvisit on GET /gathers/:id (normal page request)' do
    login_as(user)
    stale_lastvisit = 3.hours.ago.change(usec: 0)
    user.update_columns(lastvisit: stale_lastvisit)

    get gather_path(gather)

    expect(response).to have_http_status(:ok)
    expect(user.reload.lastvisit).to be > stale_lastvisit
  end
end
