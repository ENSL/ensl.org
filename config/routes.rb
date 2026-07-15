# frozen_string_literal: true

Rails.application.routes.draw do
  # Mount Action Cable for Turbo Streams / Action Cable subscriptions
  mount ActionCable.server => '/cable'

  %w[403 404 422 500].each do |code|
    get code, to: 'errors#show', code: code
  end

  namespace :api do
    namespace :v1 do
      resources :users, only: %i[show index]
      resources :teams, only: [:show]
      resources :servers, only: [:index]
      resources :maps, only: [:index]

      # Backwards compatibility for old URL format: /api/v1/servers/index.:format
      get 'users/show/:id', to: 'users#show'
      get 'users/index', to: 'users#index'
      get 'teams/show/:id', to: 'teams#show'
      get 'servers/index', to: 'servers#index'
      get 'maps/index', to: 'maps#index'
      get 'sessions/me', to: 'sessions#me'
    end
  end

  # Read-only listings built on top of AnalysisResult (ensl_analysis pipeline
  # output): player rankings first, with room for map balance / activity
  # breakdowns etc. to be added the same way later.
  namespace :analysis do
    resources :users, only: [:index]
  end

  root to: 'articles#news_index'

  resources :articles do
    resources :versions, only: %i[index show update]
    collection do
      get :news_index, path: 'news' # /articles/news
      get :news_archive, path: 'news/archive'
      get :admin, path: 'news/admin'
      get :cleanup, path: 'cleanup'
    end
  end

  resources :contests do
    collection do
      get :current
      get :scores
      get :historical, path: 'historical(/:id)'
    end
    member do
      get :confirmed_matches, path: 'confirmedmatches'
      get :recalc
    end

    resources :maps, only: %i[create destroy], module: :contests
  end

  resources :categories do
    member do
      patch :up
      patch :down
    end
  end
  resources :polls do
    member do
      get :showvotes, path: 'showvotes'
    end
  end
  # Make GET /custom_urls show the administrate view by default
  get 'custom_urls', to: 'custom_urls#administrate'
  resources :custom_urls, only: %i[create update destroy]

  resources :brackets, except: %i[index new]

  get 'comments/quote'
  resources :comments, except: [:new]
  resources :shoutmsgs, except: %i[edit new update]
  resources :teamers, except: %i[new show update] do
    collection do
      get :replace
    end
  end
  resources :teams do
    member do
      get :recover
    end
  end

  resources :gathers, except: %i[destroy new] do
    collection do
      get :refresh
      get :latest, path: 'latest/:game'
    end
    member do
      get :version
    end
  end
  get 'gather', to: 'gathers#latest', game: 'ns2'

  resources :gatherers, only: %i[create destroy update] do
    collection do
      post :pick
    end
    member do
      post :status
    end
  end

  resources :groups
  resources :groupers
  resources :forumers, only: %i[create destroy update]
  resources :topics
  resources :matches

  resources :forums do
    member do
      patch :up
      patch :down
    end
  end

  # Users: resourceful + extra member/collection actions
  resources :users do
    collection do
      get :recover
      # Session management lives in SessionsController; these legacy /users/*
      # paths are preserved for backwards compatibility and rate-limiting.
      match :login,  to: 'sessions#login',  via: %i[get post]
      match :logout, to: 'sessions#logout', via: %i[get post]
      match :forgot, to: 'sessions#forgot', via: %i[get post]
      post :passkey_options, to: 'sessions#passkey_options'
      post :passkey_authenticate, to: 'sessions#passkey_authenticate'
    end
    member do
      get :agenda
      get :history
      get :popup
    end
  end

  post 'users/:id/passkeys/options', to: 'passkeys#options', as: :user_passkey_options
  post 'users/:id/passkeys', to: 'passkeys#create', as: :user_passkeys
  delete 'users/:id/passkeys/:credential_id', to: 'passkeys#destroy', as: :user_passkey

  # Legacy compatibility: allow /users/agenda/:id
  get 'users/agenda/:id', to: 'users#agenda', as: :legacy_agenda_user

  # OmniAuth callback — accept GET (provider redirects) and POST (some setups)
  # Disallow format extensions to avoid cross-origin JS embedding attempts.
  match 'auth/:provider/callback', to: 'sessions#callback', via: %i[get post], format: false

  resources :locks, only: %i[create destroy]
  resources :contesters, except: %i[index new]

  resources :challenges, except: [:edit]
  resources :servers
  resources :predictions, only: [:create]
  resources :rounds

  resources :matches do
    member do
      get :ref
    end
    collection do
      get :admin
    end
    resources :match_proposals, path: 'proposals', as: :proposals, only: %i[index new create update]
  end

  resources :maps
  resources :log_lines
  resources :log_files
  resources :directories, except: [:index] do
    member do
      post :reconcile
    end
    collection do
      # default directory landing
      get :show, path: '', defaults: { id: 1 }
    end
  end
  resources :data_files, except: [:index] do
    collection do
      get :admin
      get :trash
    end
  end

  resources :weeks, except: %i[index show]
  resources :movies do
    member do
      post :preview
      get :download
      post :snapshot
    end
    collection do
      get :admin
    end
  end

  resources :messages, except: %i[destroy edit update]

  resources :bans
  resources :tweets
  resources :issues

  resources :posts, except: %i[index show] do
    member do
      get :quote
    end
  end

  resources :votes, only: [:create]

  # About pages
  get 'about/action'
  get 'about/staff'
  get 'about/adminpanel'
  get 'about/statistics'

  # Utility
  get 'refresh', to: 'application#refresh'
  get 'search',  to: 'application#search'
  get 'emoji/shortcodes', to: 'application#emoji_shortcodes'

  # Plugin
  get 'plugin/user', to: 'plugin#user'

  # Catch-all for unmatched routes (must be last)
  # Allow single-segment custom URLs to be resolved before the catch-all
  get ':name', to: 'custom_urls#show', requirements: { name: /\A[a-z-]{2,10}\Z/ }

  match '*path', to: 'errors#show', via: :all, defaults: { code: 404 }
end
