# Base User
User.create!(username: "admin", email: "admin@ensl.org", raw_password: "developer", steamid: "0:1:23456789")

# Base User Profile
Profile.create!(user: User.first)

# Base User Groups
Group.create!(id: Group::ADMINS, name: "Admins", founder: User.first)
Group.create!(id: Group::REFEREES, name: "Referees", founder: User.first)
Group.create!(id: Group::MOVIES, name: "Movies", founder: User.first)
Group.create!(id: Group::DONORS, name: "Donors", founder: User.first)
Group.create!(id: Group::MOVIEMAKERS, name: "Movie Makers", founder: User.first)
Group.create!(id: Group::CASTERS, name: "Streamers", founder: User.first)
Group.create!(id: Group::CHAMPIONS, name: "Champions", founder: User.first)
Group.create!(id: Group::PREDICTORS, name: "Predictors", founder: User.first)
Group.create!(id: Group::STAFF, name: "Staff", founder: User.first)

# Group Association
Grouper.create!(group_id: Group::ADMINS, user_id: User.first.id)

# Base Categories
Category.create!(name: "League", domain: Category::DOMAIN_NEWS)
Category.create!(name: "ENSL Rules", domain: Category::DOMAIN_ARTICLES)
Category.create!(name: "ENSL Guides", domain: Category::DOMAIN_ARTICLES)
Category.create!(name: "Website", domain: Category::DOMAIN_ISSUES)
Category.create!(name: "ENSL Plugin", domain: Category::DOMAIN_ISSUES)
Category.create!(name: "League", domain: Category::DOMAIN_ISSUES)
Category.create!(name: "Regional", domain: Category::DOMAIN_SITES)
Category.create!(name: "Public", domain: Category::DOMAIN_SITES)
Category.create!(name: "Competetive", domain: Category::DOMAIN_SITES)
Category.create!(name: "Official", domain: Category::DOMAIN_SITES)
Category.create!(name: "General", domain: Category::DOMAIN_FORUMS)
Category.create!(name: "ENSL", domain: Category::DOMAIN_FORUMS)
Category.create!(name: "Full Length", domain: Category::DOMAIN_MOVIES)
Category.create!(name: "Shorts", domain: Category::DOMAIN_MOVIES)
Category.create!(name: "Mock-ups", domain: Category::DOMAIN_MOVIES)
Category.create!(name: "NS1", domain: Category::DOMAIN_GAMES)
Category.create!(name: "NS2", domain: Category::DOMAIN_GAMES)

# Base Articles
Article.create!(title: "ENSL Developer", status: Article::STATUS_PUBLISHED, category_id: Category.first.id, text: "Welcome to ENSL", user: User.first)
Article.create!(id: Article::RULES, title: "Rules", status: Article::STATUS_PUBLISHED, category_id: Category.where(name: "ENSL Rules").first.id, text: "ENSL Rules", user: User.first)
Article.create!(id: Article::HISTORY, title: "History", status: Article::STATUS_PUBLISHED, category_id: Category.where(name: "ENSL Rules").first.id, text: "ENSL History", user: User.first)
Article.create!(id: Article::HOF, title: "Hall of Fame", status: Article::STATUS_PUBLISHED, category_id: Category.where(name: "ENSL Rules").first.id, text: "Hall of Fame", user: User.first)

# Base Maps
Map.create!(name: "ns_ensl_developer", category_id: Category.where(name: "NS1").first.id)
Map.create!(name: "ns2_ensl_developer", category_id: Category.where(name: "NS2").first.id)

# Base Gather types for each Game
Category.where(domain: Category::DOMAIN_GAMES).each do |game|
  Gather.create!(id: game.id, status: Gather::STATE_RUNNING, category_id: game.id)
end

# Example Poll
Poll.create!(question: "ENSL Test Poll", user: User.first)

# Example Options
Option.create!(option: "Option 1", poll: Poll.first)
Option.create!(option: "Option 2", poll: Poll.first)

# Base Forums
Forum.create!(title: "General Discussion", description: "Anything that doesn't belong in the other forums", category: Category.where(domain: Category::DOMAIN_FORUMS).first)

# Example Topic
Topic.create!(title: "Hello World!", forum_id: Forum.first.id, user: User.first, first_post: "Hello World!")

# Example Team
Team.create!(name: "ENSL", irc: "#ensl", web: "http://ensl.org", tag: "[ENSL]", country: "EU", comment: "ENSL Team", founder: User.first)
