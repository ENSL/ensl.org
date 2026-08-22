# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TeamsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def login_as(user)
    post '/sessions/login', params: { login: { username: user.username, password: user.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'GET /teams' do
    it 'renders the team index' do
      create(:team, name: 'Alpha Squad', tag: '[AS]')

      get teams_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alpha Squad')
    end
  end

  describe 'GET /teams/:id' do
    it 'renders the team page' do
      team = create(:team, name: 'Show Team', tag: '[ST]')

      get team_path(team)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Show Team')

      page = Nokogiri::HTML(response.body)
      expect(page.at_css('#team-profile img.logo')['src']).to eq('/images/icons/noavatar.png')
      expect(page.css('#team .tab').map { |panel| panel['id'] }).to eq(%w[general members matches statistics])
      expect(page.at_css('#statistics').text).to include('0.0 %')
      expect(page.at_css('#statistics').text).not_to include('NaN')
    end

    it 'keeps the join action in its own row before the team tabs' do
      team = create(:team)
      login_as(user)

      get team_path(team)

      page = Nokogiri::HTML(response.body)
      join_form = page.at_css('#team-profile > form.join-team')
      expect(join_form).to be_present
      expect(join_form.next_element['id']).to eq('team')
    end
  end

  describe 'GET /teams/new' do
    it 'returns 403 for guests' do
      get new_team_path

      expect(response).to have_http_status(:forbidden)
    end

    it 'renders for signed-in users' do
      login_as(user)

      get new_team_path

      expect(response).to have_http_status(:ok)
    end
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

    it 'returns 403 for guests' do
      expect do
        post teams_path, params: { team: { name: 'Blocked Team', tag: '[BT]' } }
      end.not_to change(Team, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 422 for invalid params' do
      login_as(admin)

      expect do
        post teams_path, params: { team: { name: '', tag: '' } }
      end.not_to change(Team, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:new)
      expect(response.body).to include('Please fix the errors below.')
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

    it 'returns 422 for invalid updates' do
      team = create(:team, name: 'Valid Team', tag: '[VT]')
      login_as(admin)

      patch team_path(team), params: { team: { name: '', tag: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:edit)
      expect(team.reload.name).to eq('Valid Team')
    end

    it 'applies only allowed rank changes and promotes joiners into the team' do
      leader = create(:user)
      team = create(:team, founder: leader)
      member = create(:teamer, team: team, rank: Teamer::RANK_MEMBER)
      joiner_user = create(:user)
      joiner = create(:teamer, team: team, user: joiner_user, rank: Teamer::RANK_JOINER)

      login_as(leader)

      patch team_path(team), params: {
        team: { name: 'Ranked Team' },
        rank: {
          member.id.to_s => Teamer::RANK_JOINER.to_s,
          joiner.id.to_s => Teamer::RANK_MEMBER.to_s
        },
        comment: {
          member.id.to_s => 'skip',
          joiner.id.to_s => 'approved'
        }
      }

      expect(response).to redirect_to(edit_team_path(team))
      expect(member.reload.rank).to eq(Teamer::RANK_MEMBER)
      expect(member.comment).to be_nil
      expect(joiner.reload.rank).to eq(Teamer::RANK_MEMBER)
      expect(joiner.comment).to eq('approved')
      expect(joiner_user.reload.team).to eq(team)
    end

    it 'forbids non-leader non-admin' do
      team = create(:team)
      login_as(user)
      patch team_path(team), params: { team: { name: 'Bad Update' } }
      expect(response.status).to eq(403)
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

    it 'returns 403 when a non-admin tries to destroy a team' do
      team = create(:team)
      login_as(user)

      expect do
        delete team_path(team)
      end.not_to change(Team, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 when a non-admin tries to recover a team' do
      team = create(:team)
      team.update!(active: false)
      login_as(user)

      get recover_team_path(team)

      expect(response).to have_http_status(:forbidden)
      expect(team.reload.active).to be false
    end
  end
end
