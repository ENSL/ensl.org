# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IssuesController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:moderator) { create(:user, :gather_moderator) }
  let(:user) { create(:user) }
  let!(:gather_category) { create(:category, id: Issue::CATEGORY_GATHER, domain: Category::DOMAIN_ISSUES, name: 'Gather Issues') }
  let!(:website_category) { create(:category, id: Issue::CATEGORY_WEBSITE, domain: Category::DOMAIN_ISSUES, name: 'Website Issues') }

  describe 'GET /issues' do
    it 'allows admins to see all allowed categories' do
      gather_issue = create(:issue, title: 'Gather issue', category: gather_category, status: Issue::STATUS_OPEN)
      website_issue = create(:issue, title: 'Website issue', category: website_category, status: Issue::STATUS_SOLVED)
      uncategorized_issue = create(:issue, title: 'No category issue', category: nil, status: Issue::STATUS_REJECTED)
      login_as(admin)

      get '/issues', params: { sort: 'title' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(gather_issue.title)
      expect(response.body).to include(website_issue.title)
      expect(response.body).to include(uncategorized_issue.title)
    end

    it 'limits moderators to their allowed categories' do
      create(:issue, title: 'Gather issue', category: gather_category, status: Issue::STATUS_OPEN)
      create(:issue, title: 'Website issue', category: website_category, status: Issue::STATUS_OPEN)
      login_as(moderator)

      get '/issues'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Gather issue')
      expect(response.body).not_to include('Website issue')
    end

    it 'returns 403 for normal users' do
      login_as(user)

      get '/issues'

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 for guests' do
      get '/issues'

      expect(response).to have_http_status(:forbidden)
    end

    it 'supports alternate sort branches for admins' do
      assigned = create(:user)
      issue = create(:issue, title: 'Sortable issue', category: gather_category, assigned: assigned, status: Issue::STATUS_OPEN)
      login_as(admin)

      %w[status assigned category unexpected].each do |sort|
        get '/issues', params: { sort: sort }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(issue.title)
      end
    end
  end

  describe 'GET /issues/new' do
    it 'renders the form for guests' do
      get '/issues/new'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end
  end

  describe 'GET /issues/:id' do
    it 'allows the author to view their issue' do
      issue = create(:issue, author: user, category: gather_category)
      login_as(user)

      get "/issues/#{issue.id}"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
    end

    it 'returns 403 for users without access' do
      issue = create(:issue, author: create(:user), category: website_category)
      login_as(user)

      get "/issues/#{issue.id}"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /issues/:id/edit' do
    it 'allows moderators to edit issues in allowed categories' do
      issue = create(:issue, category: gather_category)
      login_as(moderator)

      get "/issues/#{issue.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'returns 403 for regular users' do
      issue = create(:issue, category: gather_category)
      login_as(user)

      get "/issues/#{issue.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /issues' do
    it 'creates an issue for logged in users' do
      login_as(user)

      expect do
        post '/issues', params: {
          issue: {
            title: 'Logged in issue',
            text: 'Body for a logged in issue',
            category_id: gather_category.id
          }
        }
      end.to change(Issue, :count).by(1)

      expect(response).to redirect_to(issue_path(Issue.order(:id).last))
      expect(Issue.order(:id).last.author).to eq(user)
    end

    it 'creates an issue for guests when recaptcha succeeds' do
      allow_any_instance_of(IssuesController).to receive(:verify_recaptcha).and_return(true)

      expect do
        post '/issues', params: {
          issue: {
            title: 'Anonymous issue',
            text: 'Body for an anonymous issue',
            category_id: gather_category.id
          }
        }
      end.to change(Issue, :count).by(1)

      expect(response).to redirect_to(root_path)
    end

    it 'renders new for guests when recaptcha fails' do
      allow_any_instance_of(IssuesController).to receive(:verify_recaptcha).and_return(false)

      expect do
        post '/issues', params: {
          issue: {
            title: 'Blocked anonymous issue',
            text: 'Body for a blocked anonymous issue',
            category_id: gather_category.id
          }
        }
      end.not_to change(Issue, :count)

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'renders new for invalid issue data' do
      login_as(user)

      expect do
        post '/issues', params: { issue: { title: '', text: '', category_id: gather_category.id } }
      end.not_to change(Issue, :count)

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end
  end

  describe 'PATCH /issues/:id' do
    let!(:issue) { create(:issue, category: gather_category, author: user, title: 'Original issue') }

    it 'allows admins to update issues' do
      login_as(admin)

      patch "/issues/#{issue.id}", params: {
        issue: {
          title: 'Updated issue',
          text: issue.text,
          status: Issue::STATUS_SOLVED,
          category_id: website_category.id
        }
      }

      expect(response).to redirect_to(issue_path(issue))
      expect(issue.reload.title).to eq('Updated issue')
      expect(issue.status).to eq(Issue::STATUS_SOLVED)
    end

    it 'returns 403 when a moderator tries to move an issue outside their category' do
      login_as(moderator)

      patch "/issues/#{issue.id}", params: {
        issue: {
          title: 'Blocked move',
          text: issue.text,
          category_id: website_category.id
        }
      }

      expect(response).to have_http_status(:forbidden)
      expect(issue.reload.category).to eq(gather_category)
    end

    it 'renders edit for invalid updates' do
      login_as(admin)

      patch "/issues/#{issue.id}", params: {
        issue: {
          title: '',
          text: '',
          status: Issue::STATUS_OPEN,
          category_id: gather_category.id
        }
      }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
      expect(issue.reload.title).to eq('Original issue')
    end
  end

  describe 'DELETE /issues/:id' do
    it 'allows admins to destroy issues' do
      issue = create(:issue, category: gather_category)
      login_as(admin)

      expect do
        delete "/issues/#{issue.id}"
      end.to change(Issue, :count).by(-1)

      expect(response).to redirect_to(issues_path)
    end

    it 'returns 403 for moderators' do
      issue = create(:issue, category: gather_category)
      login_as(moderator)

      expect do
        delete "/issues/#{issue.id}"
      end.not_to change(Issue, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
