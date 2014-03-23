require 'rss/2.0'
require 'open-uri'

class TweetsController < ApplicationController
  def index
    @tweets = Tweet.all :order => "created_at DESC"
    @nobody = true
  end

  def show
    @tweet = Tweet.find(params[:id])
  end

  def refresh
    open('http://twitter.com/statuses/user_timeline/16676427.rss') do |http|
      RSS::Parser.parse(http.read, false).items.each do |item|
        unless Tweet.first :conditions => {:link => item.link}
          tweet = Tweet.new
          tweet.link = item.link
          tweet.msg = item.title.gsub(/NS2: /, "")
          tweet.created_at = DateTime.parse item.pubDate.to_s
          tweet.save
        end
      end
    end

    render :text => t(:tweets_refresh)
  end
end
