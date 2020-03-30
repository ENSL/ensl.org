Ensl::Application.routes.draw do
  if Rails.env.production?
    %w(403 404 422 500).each do |code|
      get code, to: "errors#show", code: code
    end
  end

  namespace :api do
    namespace :v1 do
      resources :users, only: [:show, :index]
      resources :teams, only: [:show]
      resources :servers, only: [:index]
      resources :maps, only: [:index]
    end
  end

  root to: "articles#news_index"

  resources :articles do
    resources :versions
  end

  get 'contests/del_map'
  get 'contests/scores'
  get 'contests/historical', to: "contests#historical"

  resources :contests do
    get "current", on: :collection
  end

  resources :log_events
  resources :categories
  resources :options
  resources :polls
  resources :custom_urls, only: [:create, :update, :destroy]
  resources :brackets

  get 'comments/quote'

  resources :comments
  resources :shoutmsgs
  resources :teamers
  resources :teams
  resources :gathers
  resources :gatherers
  resources :groups
  resources :groupers
  resources :forumers
  resources :topics
  resources :matches

  get 'forums/up'
  get 'forums/down'

  resources :forums
  resources :users do
    collection do
      get 'forgot'
      post 'forgot'
    end
  end
  resources :locks
  resources :contesters

  get "contests/:id/confirmedmatches" => "contests#confirmed_matches", as: :confirmed_matches
  resources :contests do
    member do
      get :recalc
    end
  end
  resources :challenges
  resources :servers
  resources :predictions
  resources :rounds
  resources :matches do |m|
    member do
      get :ref
    end
    collection do
      get :admin
    end
    resources :match_proposals, path: "proposals", as: :proposals, only: [:index, :new, :create, :update]
  end

  resources :maps
  resources :logs
  resources :log_files
  resources :directories
  resources :data_files
  resources :predictions
  resources :weeks
  resources :movies
  resources :messages
  # resources :sites
  resources :bans
  resources :tweets
  resources :issues
  resources :posts do |p|
    get :quote
  end

  get 'about/action'
  get 'about/staff'
  get 'about/adminpanel'
  get 'about/statistics'

  get 'refresh', to: "application#refresh"
  get 'search', to: "application#search"

  get 'news', to: "articles#news_index"
  get 'news/archive', to: "articles#news_archive"
  get 'news/admin', to: "articles#admin"
  get 'articles/cleanup'

  get 'data_files/admin'
  get 'data_files/addFile'
  get 'data_files/delFile'
  get 'data_files/trash'

  get 'directories', to: "directories#show", id: 1

  get 'gathers/refresh'
  get 'gathers/latest/:game', to: "gathers#latest", via: :get
  get 'gather', to: "gathers#latest", game: "ns2", via: :get

  get 'gatherers/:id/status', to: "gatherers#status", via: :post

  get 'groups/addUser'
  get 'groups/delUser'

  get 'movies/download'
  get 'movies/preview'
  get 'movies/snapshot'

  get 'plugin/user'

  get 'users/forgot'
  get 'users/recover'
  get 'users/agenda'
  post 'users/logout'
  post 'users/login'

  get 'users/agenda'
  get 'users/login'
  get 'users/logout'
  get 'users/popup'

  get 'votes/create'
  get "polls/showvotes/:id", to: "polls#showvotes", as: "polls_showvotes"

  get "custom_urls", to: "custom_urls#administrate"
  get ":name", to: "custom_urls#show", requirements: {name: /\A[a-z\-]{2,10}\Z/}

  get ':controller/:action', requirements: { action: /A-Za-z/ }
  get ':controller/:action/:id'
  get ':controller/:action/:id.:format'
  get ':controller/:action/:id/:id2'

  get 'teamers/replace', to: 'teamers#replace', as: 'teamers_replace'
end
