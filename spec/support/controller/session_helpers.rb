module Controllers
  module SessionHelpers
    def login_admin
      user = Group.admins.first.user
      login(user.username)
    end

    def login(username)
      user = User.where(:username => username.to_s).first
      request.session[:user] = user.id
    end

    def current_user
      User.find(request.session[:user])
    end
  end
end