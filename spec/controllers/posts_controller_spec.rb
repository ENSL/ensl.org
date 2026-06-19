# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PostsController, type: :controller do
  let(:admin) { create(:user, :admin) }

  before do
    routes.draw do
      resources :forums, only: [:show]
      resources :topics, only: [:show]
      resources :posts do
        member do
          post :trash
        end
      end
    end

    allow(controller).to receive(:safe_redirect_to) { |path| controller.redirect_to(path) }
  end

  after do
    Rails.application.reload_routes!
  end

  describe '#trash' do
    it 'redirects to the topic when the topic remains persisted' do
      session[:user] = admin.id
      topic = instance_double(Topic, persisted?: true)
      post_record = double('Post', can_destroy?: true, trash: true, topic: topic)
      allow(Post).to receive(:find).and_return(post_record)
      allow(controller).to receive(:polymorphic_path).with(topic).and_return('/topics/1')

      post :trash, params: { id: '1' }

      expect(response).to redirect_to('/topics/1')
      expect(flash[:notice]).to eq(I18n.t(:posts_trash))
    end

    it 'redirects to the forum when the topic is no longer persisted' do
      session[:user] = admin.id
      forum = instance_double(Forum)
      topic = instance_double(Topic, persisted?: false, forum: forum)
      post_record = double('Post', can_destroy?: true, trash: true, topic: topic)
      allow(Post).to receive(:find).and_return(post_record)
      allow(controller).to receive(:polymorphic_path).with(forum).and_return('/forums/1')

      post :trash, params: { id: '1' }

      expect(response).to redirect_to('/forums/1')
      expect(flash[:notice]).to eq(I18n.t(:posts_trash))
    end

    it 'returns 403 when the user cannot trash the post' do
      session[:user] = admin.id
      topic = instance_double(Topic, persisted?: true)
      post_record = double('Post', can_destroy?: false, topic: topic)
      allow(Post).to receive(:find).and_return(post_record)

      post :trash, params: { id: '1' }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
