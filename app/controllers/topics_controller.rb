class TopicsController < ApplicationController
  before_filter :get_topic, only: [:show, :reply, :edit, :update, :destroy]
  layout 'forums'

  def index
    render partial: true, locals: {page: params[:p].to_i}
  end

  def show
    raise AccessError unless @topic.can_show? cuser
    @posts = @topic.posts.basic.paginate(:page => params[:page],
                                         :per_page => Topic::POSTS_PAGE)

    return_here
    @topic.record_view_count(request.remote_ip, cuser.nil?)
    @topic.read_by! cuser if cuser
    @topic.forum.read_by! cuser if cuser
    @newpost = Post.new
    @newpost.topic = @topic
    @newpost.user = cuser
    @lock = (@topic.lock ? @topic.lock : Lock.new(:lockable => @topic))
  end

  def reply
    @post = @topic.posts.build
    raise AccessError unless @post.can_create? cuser
    if request.xhr?
      render 'quickreply', layout: false
    else
      render
    end
  end

  def new
    @topic = Topic.new
    @topic.forum = Forum.find(params[:id])
    raise AccessError unless @topic.can_create? cuser
  end

  def edit
    raise AccessError unless @topic.can_update? cuser
  end

  def create
    @topic = Topic.new(params[:topic])
    @topic.user = cuser
    raise AccessError unless @topic.can_create? cuser

    if @topic.save
      flash[:notice] = t(:topics_create)
      redirect_to(@topic)
    else
      render :new
    end
  end

  def update
    raise AccessError unless @topic.can_update? cuser
    if @topic.update_attributes(params[:topic])
      flash[:notice] = t(:topics_update)
      redirect_to(@topic)
    else
      render :edit
    end
  end

  def destroy
    raise AccessError unless @topic.can_destroy? cuser
    @topic.destroy
    redirect_to(topics_url)
  end

  private

  def get_topic
    @topic = Topic.find(params[:id])
  end
end
