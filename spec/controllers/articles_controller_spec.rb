require 'rails_helper'

RSpec.describe ArticlesController, type: :controller do
  let!(:category) { create(:category, domain: Category::DOMAIN_NEWS) }
  let!(:params) { FactoryBot.attributes_for(:article).merge!(category_id: category.id) }
  let!(:invalid_params) { params.merge(:title => (0..150).map { (65 + rand(26)).chr }.join) }
  let!(:article) { create(:article, category_id: category.id, user_id: admin.id) }
  let!(:admin) { create(:user, :admin) }
  let!(:user) { create(:user) }

  describe 'GET #index' do
    it "renders the template" do
      get :index
      expect(response).to render_template("index")
    end

    it "assigns categories" do
      get :index
      expect(assigns(:categories)).to eq(Category.ordered.nospecial.domain Category::DOMAIN_ARTICLES)
    end
  end

  describe 'GET #news_index' do
    it "renders the news index" do
      get :news_index
      expect(response).to render_template("news_index")
    end
  end

  describe 'GET #news_archive' do
    it "renders the news archive" do
      get :news_archive
      expect(response).to render_template("news_archive")
    end
  end

  describe 'GET #admin' do
    it "renders the template" do
      login_admin
      get :admin
      expect(response).to render_template("admin")
    end
  end

  describe 'GET #edit' do
    let!(:article) { create(:article, category_id: category.id, user_id: admin.id) }

    it "renders the template" do
      login_admin
      get :edit, params: {id: article.id}
      expect(response).to render_template("edit")
    end
  end

  context 'POST' do
    before(:each) do
      expect(:params).not_to eq(:invalid_params)
    end

    describe 'with valid values' do
      it "creates the model" do
        login_admin
        post :create, params: {:article => params}
        # Article.any_instance.should_receive(:update_attributes).with(params)
        expect(Article.last).to have_attributes(params)
      end

      it "redirects correctly" do
        login_admin
        post :create, params: {:article => params}
        expect(response).to redirect_to(article_path(Article.last))
      end
    end

    describe 'with invalid values' do
      it "does not create the model" do
        login_admin
        count = Article.count
        post :create, params: {:article => invalid_params}
        # Article.any_instance.should_receive(:update_attributes).with(params)
        expect(Article.count).to eq(count)
      end

      it "renders :new" do
        login_admin
        post :create, params: {:article => invalid_params}
        expect(response).to render_template("new")
      end
    end
  end

  context 'PUT' do
    describe 'with valid values' do
      it "updates the model" do
        login_admin
        params = FactoryBot.attributes_for(:article).merge!(category_id: category.id)
        put :update, params: {:id => article.id, :article => params}
        # Article.any_instance.should_receive(:update_attributes).with(params)
        expect(Article.find(article.id).attributes).not_to eq(article.attributes)
      end

      it "redirects correctly" do
        login_admin
        put :update, params: {:id => article.id, :article => params}
        expect(response).to redirect_to(article_path(Article.last))
      end
    end

    describe 'with invalid values' do
      it "does not update the model" do
        login_admin
        put :update, params: {:id => article.id, :article => invalid_params}
        expect(Article.find(article.id).attributes).to eq(article.attributes)
      end

      it "renders :edit" do
        login_admin
        put :update, params: {:id => article.id, :article => invalid_params}
        expect(response).to render_template("edit")
      end
    end
  end

  context 'DELETE' do
    describe 'with valid parameters' do
      it "deletes the model" do
        login_admin
        count = Article.count
        delete :destroy, params: {:id => article.id}

        expect(Article.where(id: article.id).count).to eq(0)
        expect(Article.count).to eq(count - 1)
        # Article.any_instance.should_receive(:update_attributes).with(params)
      end

      it "redirects correctly" do
        login_admin
        request.env["HTTP_REFERER"] = "where_i_came_from"
        delete :destroy, params: {:id => article.id}

        expect(response).to redirect_to("where_i_came_from")
      end
    end

    describe 'without access' do
      it "does not delete the model" do
        login(user.username)
        count = Article.count
        delete :destroy, params: {:id => article.id}

        expect(Article.count).to eq(count)
      end
    end
  end
end
