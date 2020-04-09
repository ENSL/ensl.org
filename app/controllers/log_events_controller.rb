class LogEventsController < ApplicationController
  # GET /log_events
  # GET /log_events.xml
  def index
    @log_events = LogEvent.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @log_events }
    end
  end

  # GET /log_events/1
  # GET /log_events/1.xml
  def show
    @log_event = LogEvent.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @log_event }
    end
  end

  # GET /log_events/new
  # GET /log_events/new.xml
  def new
    @log_event = LogEvent.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @log_event }
    end
  end

  # GET /log_events/1/edit
  def edit
    @log_event = LogEvent.find(params[:id])
  end

  # POST /log_events
  # POST /log_events.xml
  def create
    @log_event = LogEvent.new(params[:log_event])

    respond_to do |format|
      if @log_event.save
        flash[:notice] = t(:logevent_create)
        format.html { redirect_to(@log_event) }
        format.xml  { render xml: @log_event, :status => :created, :location => @log_event }
      else
        format.html { render :new }
        format.xml  { render xml: @log_event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /log_events/1
  # PUT /log_events/1.xml
  def update
    @log_event = LogEvent.find(params[:id])

    respond_to do |format|
      if @log_event.update_attributes(params[:log_event])
        flash[:notice] = t(:logevent_update)
        format.html { redirect_to(@log_event) }
        format.xml  { head :ok }
      else
        format.html { render :edit }
        format.xml  { render xml: @log_event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /log_events/1
  # DELETE /log_events/1.xml
  def destroy
    @log_event = LogEvent.find(params[:id])
    @log_event.destroy

    respond_to do |format|
      format.html { redirect_to(log_events_url) }
      format.xml  { head :ok }
    end
  end
end
