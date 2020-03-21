require 'rails_helper'
require 'mime/types'

RSpec.describe UsersController, type: :controller do
  let!(:params) { FactoryBot.attributes_for(:user) }
  let!(:invalid_params) { params.merge(:steamid => (50..150).map { (65 + rand(26)).chr }.join) }
  let!(:admin) { create(:user, :admin) } 
  let!(:user) { create(:user) }

  before :all do
    create(:user)
  end

  # TODO: check flash

  describe 'GET #index' do
    it "renders the template" do
      get :index
      expect(response).to render_template("index")
    end

    it "assigns users" do
      get :index
      # TODO
      expect(assigns(:users))
    end

    # TODO Test pagination + search
  end

  describe 'GET #popup' do
    context 'with valid user' do
      it "renders the template" do
        login_admin
        get :popup, params: {:id => user.id}, xhr: true
        expect(response).to render_template("popup")
      end
      # Check for pages TODO
    end
  end

  describe 'GET #agenda' do
    context 'with valid user' do
      it "renders the template" do
        login user.username
        get :agenda, params: {:id => user.id}
        expect(response).to render_template("agenda")
      end
    end

    context 'with admin access' do
      it "renders the template" do
        login_admin
        get :agenda, params: {:id => user.id}
        expect(response).to render_template("agenda")
      end
      # Check for pages TODO
    end

    context 'with valid user access another user' do
      it "respond with 403" do
        user2 = create(:user)
        login user.username
        get :agenda, params: {:id => user2.id}
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #history' do
    context 'with admin access' do
      it "renders the template" do
        login_admin
        get :history, params: {:id => user.id}
        expect(response).to render_template("history")
      end
      # Check for pages TODO
    end

    context 'without admin access' do
      it "respond with 403" do
        user2 = create(:user)
        login user.username
        get :history, params: {:id => user2.id}
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #edit' do
    let!(:user) { create(:user) }

    it "renders the template" do
      login_admin
      get :edit, params: {id: user.id}
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
        post :create, params: {:user => params}
        # user.any_instance.should_receive(:update_attributes).with(params)
        # FIXME: ignore lastvisit and raw_password
        expect(User.last).to have_attributes(params.except(:raw_password,))
      end

      it "redirects correctly" do
        login_admin
        post :create, params: {:user => params}
        expect(response).to redirect_to(user_path(User.last))
      end
    end

    describe 'with invalid values' do
      it "does not create the model" do
        login_admin
        count = User.count
        post :create, params: {:user => invalid_params}
        # user.any_instance.should_receive(:update_attributes).with(params)
        expect(User.count).to eq(count)
      end

      it "renders :new" do
        login_admin
        post :create, params: {:user => invalid_params}
        expect(response).to render_template("new")
      end
    end
  end

  context 'PUT' do
    describe 'with valid values' do
      it "updates the model" do
        login_admin
        params = FactoryBot.attributes_for(:user)
        put :update, params: {:id => user.id, :user => params}
        # user.any_instance.should_receive(:update_attributes).with(params)
        expect(User.find(user.id).attributes).not_to eq(user.attributes)
      end

      it "redirects correctly" do
        login_admin
        request.env["HTTP_REFERER"] = "where_i_came_from"
        put :update, params: {:id => user.id, :user => params}

        expect(response).to redirect_to("where_i_came_from")
      end
    end

    describe 'with invalid values' do
      it "does not update the model" do
        login_admin
        put :update, params: {:id => user.id, :user => invalid_params}
        expect(User.find(user.id).attributes).to eq(user.attributes)
      end

      it "renders :edit" do
        login_admin
        put :update, params: {:id => user.id, :user => invalid_params}
        expect(response).to render_template("edit")
      end
    end
  end

  context 'DELETE' do
    describe 'with valid parameters' do
      it "deletes the model" do
        login_admin
        count = User.count
        delete :destroy, params: {:id => user.id}

        expect(User.where(id: user.id).count).to eq(0)
        expect(User.count).to eq(count - 1)
        # user.any_instance.should_receive(:update_attributes).with(params)
      end

      it "redirects correctly" do
        login_admin
        request.env["HTTP_REFERER"] = "where_i_came_from"
        delete :destroy, params: {:id => user.id}

        expect(response).to redirect_to(users_path())
      end
    end

    describe 'without access' do
      it "does not delete the model" do
        login(user.username)
        count = User.all.count
        delete :destroy, params: {:id => user.id}

        expect(User.count).to eq(count)
      end
    end
  end

  context 'POST #login' do
    describe 'with valid values' do
      it "set the session ID (logs in)" do
        post :login, params: {login: {username: user.username, password: user.raw_password}}
        expect(session[:user]).to eq(user.id)
      end

      # TODO
      #expect(User).to have_received(:authenticate).with(params[:login])

      it "redirects correctly" do
        request.env["HTTP_REFERER"] = "where_i_came_from"
        post :login, params: {login: {username: user.username, password: user.raw_password}}
        expect(response).to redirect_to("where_i_came_from")
      end
    end

    describe 'with invalid values' do
      it "fails to set the session ID" do
        post :login, params: {login: {username: user.username, password: user.raw_password + "foo"}}
        expect(session[:user]).not_to eq(user.id)
      end
    end

    describe 'banned accounts cannot log in' do
      it "fails to set the session ID" do
        ban = create(:ban, user: user)
        post :login, params: {login: {username: user.username, password: user.raw_password}}
        expect(session[:user]).not_to eq(user.id)
      end
    end
  end

  context 'GET #forgot' do
    describe 'with valid values' do
      it "renders the template" do
        get :forgot
        expect(response).to render_template("forgot")
      end
    end
  end

  context 'POST #forgot' do
    describe 'with valid values' do
      it "renders the template" do
        #TODO: mock this function
        post :forgot, params: {username: user.username, email: user.email}
        expect(response).to render_template("forgot")
      end

      it "calls the function" do
        # User.any_instance.stub(:send_new_password).and_return(true)
        allow_any_instance_of(User).to receive(:send_new_password).and_return(true)
        post :forgot, params: {username: user.username, email: user.email}
        # FIXME
        # expect_any_instance_of(User).to receive(:send_new_password)
      end
    end
  end
end