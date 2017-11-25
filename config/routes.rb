Ensl::Application.routes.draw do

  %w(403 404 422 500).each do |code|
    get code, to: "errors#show", code: code
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

  get "contests/del_map"
  get "contests/scores"
  get "contests/historical", to: "contests#historical"

  resources :contests do
    get "current", on: :collection
  end

  resources :log_events
  resources :categories
  resources :options
  resources :polls

  get "comments/quote"

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

  get "forums/up"
  get "forums/down"

  resources :forums
  resources :users
  resources :locks
  resources :contesters

  get "contests/:id/confirmedmatches" => "contests#confirmed_matches", as: :confirmed_matches
  resources :contests
  resources :challenges
  resources :servers
  resources :predictions
  resources :rounds

  get "matches/ref/:id" => "matches#ref", as: :match_ref
  resources :matches do
    get :admin, to: "matches#admin", on: :collection
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

  get "posts/quote"

  resources :posts
  resources :brackets

  get "about/action"
  get "about/staff"
  get "about/statistics"

  # match "refresh", to: "application#refresh"
  # match "search", to: "application#search"

  get "news", to: "articles#news_index"
  get "news/archive", to: "articles#news_archive"
  get "news/admin", to: "articles#admin"
  get "articles/cleanup"

  get "data_files/admin"
  match "data_files/addFile", via: [:get, :post]
  match "data_files/delFile", via: [:get, :post]
  match "data_files/trash", via: [:get, :post]

  match "contests/recalc", via: [:get, :post]

  get "directories", to: "directories#show", id: 1

  match "gathers/refresh", via: [:get, :post]
  match "gathers/latest/:game", to: "gathers#latest", via: :get
  match "gather", to: "gathers#latest", game: "ns2", via: :get

  match "gatherers/:id/status", to: "gatherers#status", via: :post

  post "groups/addUser"
  post "groups/delUser"

  get "movies/download"
  get "movies/preview"
  get "movies/snapshot"

  get "plugin/user"

  match "users/forgot", via: [:get, :post]
  get "users/agenda"
  match "users/logout", via: [:get, :post]
  match "users/login", via: [:get, :post]
  get "users/popup"

  post "votes/create"
  get "polls/showvotes/:id", to: "polls#showvotes", as: "polls_showvotes"

  get "custom_urls", to: "custom_urls#administrate"
  resources :custom_urls, only: [:create, :update, :destroy]

  get ":name", to: "custom_urls#show", requirements: {name: /\A[a-z\-]{2,10}\Z/}

  match ":controller/:action", requirements: { action: /A-Za-z/ }, via: [:get, :post]
  match ":controller/:action/:id", via: [:get, :post]
  match ":controller/:action/:id.:format", via: [:get, :post]
  match ":controller/:action/:id/:id2", via: [:get, :post]

  # match "teamers/replace", to: "teamers#replace", as: "teamers_replace"
end
