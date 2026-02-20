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

  root to: 'articles#news_index'

  resources :articles do
    resources :versions
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
      delete :del_map
      get :scores
      get :historical, path: 'historical(/:id)'
    end
    member do
      get :confirmed_matches, path: 'confirmedmatches'
      get :recalc
    end
  end

  resources :log_events
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

  resources :brackets

  get 'comments/quote'
  resources :comments
  resources :shoutmsgs
  resources :teamers do
    collection do
      get :replace
    end
  end
  resources :teams do
    member do
      get :recover
    end
  end

  resources :gathers do
    collection do
      get :refresh
      get :latest, path: 'latest/:game'
    end
    member do
      get :version
      post :pick
    end
  end
  get 'gather', to: 'gathers#latest', game: 'ns2'

  resources :gatherers do
    member do
      post :status
    end
  end

  resources :groups
  resources :groupers
  resources :forumers
  resources :topics
  resources :matches

  get 'forums/up'
  get 'forums/down'
  resources :forums

  # Users: resourceful + extra member/collection actions
  resources :users do
    collection do
      get :forgot
      post :forgot
      get  :recover
      # simple session-style endpoints (non-REST) kept under users for legacy
      post :login
      post :logout
      get  :login
      get  :logout
    end
    member do
      get :agenda
      get :history
      get :popup
    end
  end

  # Legacy compatibility: allow /users/agenda/:id
  get 'users/agenda/:id', to: 'users#agenda', as: :legacy_agenda_user

  # OmniAuth callback — accept GET (provider redirects) and POST (some setups)
  # Disallow format extensions to avoid cross-origin JS embedding attempts.
  match 'auth/:provider/callback', to: 'users#callback', via: %i[get post], format: false

  resources :locks
  resources :contesters

  resources :challenges
  resources :servers
  resources :predictions
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
  resources :logs
  resources :log_files
  resources :directories do
    member do
      post :reconcile
    end
    collection do
      # default directory landing
      get :show, path: '', defaults: { id: 1 }
    end
  end
  resources :data_files do
    collection do
      get :admin
      get :addFile
      get :delFile
      get :trash
    end
  end

  resources :weeks
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

  resources :messages

  resources :bans
  resources :tweets
  resources :issues

  resources :posts do
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

  # Plugin
  get 'plugin/user', to: 'plugin#user'

  # Catch-all for unmatched routes (must be last)
  # Allow single-segment custom URLs to be resolved before the catch-all
  get ':name', to: 'custom_urls#show', requirements: { name: /\A[a-z-]{2,10}\Z/ }

  match '*path', to: 'errors#show', via: :all, defaults: { code: 404 }
end
