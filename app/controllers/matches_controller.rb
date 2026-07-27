# frozen_string_literal: true

class MatchesController < ApplicationController
  before_action :load_match, except: %i[index new create admin]

  def index
    @matches = Match.active
  end

  def show
    @ownpred = @match.predictions.where(user_id: cuser.id) if cuser
    @newpred = @match.predictions.build
  end

  def new
    @match = Match.new
    @match.contest = Contest.find params[:id]
    raise AccessError unless @match.can_create? cuser
  end

  def admin
    @matches = Match.active.includes(:contest, :contester1, :contester2, :map1, :map2, :referee)
                    .all.group_by { |t| t.week.to_s }.to_a.reverse
    render layout: 'full'
  end

  def extra; end

  def ref
    raise AccessError unless @match.can_update? cuser, [:report]

    @n = 0
  end

  def edit
    raise AccessError unless @match.can_update? cuser, [:contester1_id]
  end

  def create
    @match = Match.new(Match.params(params, cuser))
    raise AccessError unless @match.can_create? cuser

    save_and_respond(@match, notice: :matches_create,
                             location: edit_contest_path(@match.contest, contest: 'matches'),
                             template: :new) { @match.save }
  end

  def update
    raise AccessError unless @match.can_update? cuser, params[:match]

    Match.normalize_matchers_attributes!(params[:match])

    return handle_match_update_success if @match.update(Match.params(params, cuser))

    handle_match_update_failure
  end

  def hltv
    raise AccessError unless @match.can_update? cuser, [:hltv]

    if params[:commit].include?(t(:hltv_send))
      @match.hltv_record(params[:addr], params[:pwd])
      flash[:notice] = t(:hltv_recording)
    elsif params[:commit].include?(t(:hltv_move))
      sleep(90) if params[:wait] == '1'
      @match.hltv_move(params[:addr], params[:pwd])
      flash[:notice] = t(:hltv_moved)
    elsif params[:commit].include?(t(:hltv_stop))
      sleep(90) if params[:wait] == '1'
      @match.hltv_stop
      flash[:notice] = t(:hltv_stopped)
    end
    redirect_to action: 'show'
  end

  def destroy
    raise AccessError unless @match.can_destroy? cuser

    @match.destroy
    flash[:notice] = t(:matches_destroy)
    redirect_to edit_contest_path(@match.contest, anchor: 'matches')
  end

  private

  def load_match
    @match = Match.find params[:id]
  end

  def handle_match_update_success
    respond_to do |format|
      format.xml { head :ok }
      format.html { redirect_after_match_update }
    end
  end

  def handle_match_update_failure
    flash.now[:error] = @match.errors.full_messages.to_sentence.presence || t(:error)
    return render_ref_failure if ref_match_referer?

    render :edit, status: :unprocessable_content
  end

  def redirect_after_match_update
    flash[:notice] = t(:matches_update)
    admin_match_referer? ? redirect_to_back : redirect_to(@match)
  end

  def render_ref_failure
    ref
    render :ref, status: :unprocessable_content
  end

  def admin_match_referer?
    request.referer.present? && URI(request.referer).path.include?('admin')
  end

  def ref_match_referer?
    request.referer.present? && URI(request.referer).path == ref_match_path(@match)
  end
end
