# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Gathers version endpoint', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:gather) { create(:gather) }

  def login_as(user)
    post '/sessions/login', params: { login: { username: user.username, password: user.raw_password } }
    follow_redirect! if response.redirect?
  end

  it 'updates user lastvisit on GET /gathers/:id/version' do
    login_as(user)
    stale_lastvisit = 3.hours.ago.change(usec: 0)
    user.update!(lastvisit: stale_lastvisit)

    get version_gather_path(gather), headers: { 'ACCEPT' => 'application/json' }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include('id' => gather.id)
    expect(user.reload.lastvisit).to be > stale_lastvisit
  end

  it 'broadcasts when GET /gathers/:id/version changes the gather status' do
    login_as(user)
    allow_any_instance_of(Gather).to receive(:refresh) { |record, _actor| record.status = Gather::STATE_FINISHED }
    allow(Gathers::Broadcaster).to receive(:call)

    get version_gather_path(gather), headers: { 'ACCEPT' => 'application/json' }

    expect(response).to have_http_status(:ok)
    expect(Gathers::Broadcaster).to have_received(:call).with(instance_of(Gather))
  end

  it 'updates user lastvisit on GET /gathers/:id (normal page request)' do
    login_as(user)
    stale_lastvisit = 3.hours.ago.change(usec: 0)
    user.update!(lastvisit: stale_lastvisit)

    get gather_path(gather)

    expect(response).to have_http_status(:ok)
    expect(user.reload.lastvisit).to be > stale_lastvisit
  end

  it 'renders GET /gathers/:id for guests' do
    get gather_path(gather)

    expect(response).to have_http_status(:ok)
  end

  it 'reactivates a leaving gatherer on GET /gathers/:id' do
    login_as(user)
    gatherer = create(:gatherer, gather: gather, user: user, status: Gatherer::STATE_LEAVING)

    get gather_path(gather)

    expect(response).to have_http_status(:ok)
    expect(gatherer.reload.status).to eq(Gatherer::STATE_ACTIVE)
  end

  it 'redirects GET /gather to the latest gather for the requested game' do
    ns2 = create(:category, :game, name: 'NS2')
    latest_gather = create(:gather, category: ns2)

    get '/gathers/latest/NS2'

    expect(response).to redirect_to(gather_path(latest_gather))
  end

  it 'creates gathers for admins' do
    category = create(:category, :game)
    login_as(admin)
    allow(Gathers::Broadcaster).to receive(:call)

    expect do
      post gathers_path, params: { gather: { category_id: category.id } }, headers: { 'HTTP_REFERER' => '/' }
    end.to change(Gather, :count).by(1)

    expect(response).to redirect_to('/')
  end

  it 'returns 403 when non-admins create gathers' do
    category = create(:category, :game)
    login_as(user)

    expect do
      post gathers_path, params: { gather: { category_id: category.id } }
    end.not_to change(Gather, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it 'updates gathers for admins' do
    login_as(admin)
    allow(Gathers::Broadcaster).to receive(:call)

    patch gather_path(gather), params: { gather: { turn: 1 } }

    expect(response).to redirect_to(gather_path(gather))
    expect(gather.reload.turn).to eq(1)
    expect(Gathers::Broadcaster).to have_received(:call).with(instance_of(Gather))
  end

  it 'still redirects when a gather update is invalid' do
    login_as(admin)
    allow_any_instance_of(Gather).to receive(:update).and_return(false)
    allow(Gathers::Broadcaster).to receive(:call)

    patch gather_path(gather), params: { gather: { turn: 1 } }

    expect(response).to redirect_to(gather_path(gather))
    expect(Gathers::Broadcaster).not_to have_received(:call)
  end

  it 'returns 403 when non-admins update gathers' do
    login_as(user)

    patch gather_path(gather), params: { gather: { turn: 1 } }

    expect(response).to have_http_status(:forbidden)
  end
end
