require 'rails_helper'

RSpec.describe 'TeamsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def login_as(u)
    post '/users/login', params: { login: { username: u.username, password: u.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'POST /teams (create)' do
    it 'allows admin to create a team' do
      login_as(admin)
      post '/teams', params: { team: { name: 'Req Team', tag: '[R]' } }
      expect(response).to redirect_to(%r{/teams/\d+})
      follow_redirect!
      expect(response.body).to include('Req Team')
      expect(Team.where(name: 'Req Team').exists?).to be true
    end
  end

  describe 'PATCH /teams/:id (update)' do
    it 'allows leader or admin to update a team' do
      team = create(:team)
      login_as(admin)
      patch team_path(team), params: { team: { name: 'Updated Name' } }
      expect(response).to redirect_to(edit_team_path(team))
      follow_redirect!
      expect(response.body).to include('Updated Name')
      expect(team.reload.name).to eq('Updated Name')
    end

    it 'forbids non-leader non-admin' do
      team = create(:team)
      login_as(user)
      patch team_path(team), params: { team: { name: 'Bad Update' } }
      expect(response.status).to eq(403)
    end
  end

  describe 'POST /teamers (join)' do
    it 'allows signed-in user to request to join a team' do
      team = create(:team)
      login_as(user)
      post '/teamers', params: { teamer: { team_id: team.id, user_id: user.id } }
      expect(response).to redirect_to(/.*/)
      expect(Teamer.where(team: team, user: user).joining.exists?).to be true
    end
  end

  describe 'DELETE /teams/:id (destroy) and recover' do
    it 'soft-deletes a team with matches and recovers it (admin)' do
      team = create(:team)
      contest = create(:contest)
      cont1 = create(:contester, contest: contest, team: team)
      cont2 = create(:contester, contest: contest)
      create(:match, contest: contest, contester1: cont1, contester2: cont2)

      login_as(admin)
      delete team_path(team)
      expect(response).to redirect_to(teams_path)
      expect(team.reload.active).to be false

      get recover_team_path(team)
      expect(response).to redirect_to(teams_path)
      expect(team.reload.active).to be true
    end

    it 'fully destroys a team without matches' do
      team = create(:team)
      login_as(admin)
      delete team_path(team)
      expect(response).to redirect_to(teams_path)
      expect(Team.exists?(team.id)).to be false
    end
  end
end
