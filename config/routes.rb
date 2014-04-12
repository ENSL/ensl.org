Ensl::Application.routes.draw do
	root to: "articles#news_index"

	resources :articles do
		resources :versions
	end

	resources :contests do
		get 'current', on: :collection
	end

  resources :log_events
	resources :categories
	resources :options
	resources :polls

  match 'comments/quote'

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

  match 'forums/up'
  match 'forums/down'

	resources :forums
	resources :users
	resources :locks
	resources :contesters
	resources :contests
	resources :challenges
	resources :servers
	resources :predictions
	resources :rounds
	resources :matches
	resources :maps
	resources :logs
	resources :log_files
	resources :directories
  resources :data_files
	resources :predictions
	resources :weeks
	resources :movies
	resources :messages
	resources :sites
	resources :bans
	resources :tweets
	resources :issues
  
  match 'posts/quote'

	resources :posts
	resources :brackets

  match 'about/action'
  match 'about/staff'
  match 'about/statistics'

  match 'refresh', to: "application#refresh"
  match 'search', to: "application#search"

  match 'news', to: "articles#news_index"
  match 'news/archive', to: "articles#news_archive"
  match 'news/admin', to: "articles#admin"
  match 'articles/cleanup'

  match 'contests/historical', to: "contests#historical"

  match 'data_files/admin'
  match 'data_files/addFile'
  match 'data_files/delFile'
  match 'data_files/trash'

  match 'contesters/recalc'
  match 'contests/scores'
  match 'contests/del_map'

  match 'directories', to: "directories#show", id: 1

  match 'gathers/refresh'
  match 'gathers/latest/:game', to: "gathers#latest", via: :get
  match 'gather', to: "gathers#latest", game: "ns2", via: :get  

  match 'groups/addUser'
  match 'groups/delUser'

  match 'movies/download'
  match 'movies/preview'
  match 'movies/snapshot'

  match 'plugin/esi'
  match 'plugin/user'
  match 'plugin/ban'
  match 'plugin/hltv_req'
  match 'plugin/hltv_move'
  match 'plugin/hltv_stop'

  match 'users/forgot'
  match 'users/recover'
  match 'users/agenda'
  match 'users/logout'
  match 'users/login'

  match 'users/agenda'
  match 'users/login'
  match 'users/logout'
  match 'users/popup'
  match 'users/forgot', to: "users#forgot"

  match 'votes/create'

	match ':controller/:action', requirements: { action: /A-Za-z/ }
	match ':controller/:action/:id'
	match ':controller/:action/:id.:format'
	match ':controller/:action/:id/:id2'

  namespace :api do
    namespace :v1 do
      resources :users
    end
  end
end
