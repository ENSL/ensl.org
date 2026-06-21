# frozen_string_literal: true

class Notifications < ActionMailer::Base
  default from: 'staff@ensl.org'

  def password(user, password)
    @user = user
    @pass = password
    mail to: user.email,
         subject: 'ENSL account password',
         content_type: 'multipart/alternative'
  end

  def pm(user, private_message)
    @user = user
    @pm = private_message
    mail to: user.email,
         subject: 'New ENSL private message',
         content_type: 'multipart/alternative'
  end

  def gather(user, gather)
    @user = user
    @gather = gather
    mail to: user.email,
         subject: 'ENSL gather running',
         content_type: 'multipart/alternative'
  end

  def comments(user, object)
    @user = user
    @object = object
    mail to: user.email,
         subject: 'New ENSL comments',
         content_type: 'multipart/alternative'
  end

  def challenge(user, challenge)
    @user = user
    @challenge = challenge
    mail to: user.email,
         subject: 'New ENSL challenge',
         content_type: 'multipart/alternative'
  end

  def match(user, match)
    @user = user
    @match = match
    mail to: user.email,
         subject: 'New ENSL match',
         content_type: 'multipart/alternative'
  end

  def news(user, news)
    @user = user
    @news = news
    mail to: user.email,
         subject: "News on ENSL: #{news.title}",
         content_type: 'multipart/alternative'
  end

  def article(user, article)
    @user = user
    @article = article
    mail to: user.email,
         subject: "News on ENSL: #{article.title}",
         content_type: 'multipart/alternative'
  end
end
