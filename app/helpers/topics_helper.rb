module TopicsHelper
  def lastpost topic
    topic_url(topic, :page => topic.last_page, :anchor => "post_#{topic.posts.last.id}")
  end
end
