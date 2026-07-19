# frozen_string_literal: true

class Notifications < ApplicationMailer
  default from: 'staff@ensl.org'

  def password(user, password)
    @user = user
    @pass = password
    mail to: user.email,
         subject: 'ENSL account password'
  end

  def login_otp(user, code)
    @user = user
    @code = code
    mail to: user.email,
         subject: 'ENSL login verification code'
  end

  def pm(user, private_message)
    @user = user
    @pm = private_message
    mail to: user.email,
         subject: 'New ENSL private message'
  end

  def gather(user, gather)
    @user = user
    @gather = gather
    mail to: user.email,
         subject: 'ENSL gather running'
  end

  def comments(user, object)
    @user = user
    @object = object
    mail to: user.email,
         subject: 'New ENSL comments'
  end

  def challenge(user, challenge)
    @user = user
    @challenge = challenge
    mail to: user.email,
         subject: 'New ENSL challenge'
  end

  def match(user, match)
    @user = user
    @match = match
    mail to: user.email,
         subject: 'New ENSL match'
  end

  def news(user, news)
    @user = user
    @news = news
    mail to: user.email,
         subject: "News on ENSL: #{news.title}"
  end

  def article(user, article)
    @user = user
    @article = article
    mail to: user.email,
         subject: "News on ENSL: #{article.title}"
  end
end
