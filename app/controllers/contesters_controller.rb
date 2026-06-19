# frozen_string_literal: true

class ContestersController < ApplicationController
  before_action :load_contester, only: %i[show edit update recover destroy recalc]

  def show
    @matches = Match.future.unfinished.ordered.of_contester @contester
    @results = Match.finished.ordered.of_contester @contester

    raise AccessError unless @contester&.contest && @contester.team

    @members = if @contester.contest.status == Contest::STATUS_CLOSED
                 @contester.team.teamers.distinct.ordered
               else
                 @contester.team.teamers.active.distinct.ordered
               end
  end

  def edit
    raise AccessError unless @contester.can_update? cuser
  end

  def create
    contester_params = Contester.params(params, cuser)
    @contester = Contester.new(contester_params)
    @contester.user = cuser
    raise AccessError unless @contester.can_create?(cuser, contester_params)

    if @contester.contest.contest_type == Contest::TYPE_LADDER
      @contester.score = @contester.contest.contesters.active.count + 1
    end

    if @contester.save
      flash[:notice] = t(:contests_join)
      redirect_to edit_contest_path(@contester.contest_id, anchor: 'teams')
    else
      flash.now[:error] = @contester.errors.full_messages.to_sentence.presence || t(:error)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    raise AccessError unless @contester.can_update? cuser

    if @contester.contest.contest_type == Contest::TYPE_LADDER
      old_rank = @contester.score
      new_rank = params[:contester][:score].to_i
      raise Error, t(:rank_invalid) unless new_rank.positive? &&
                                           (new_rank <= @contester.contest.contesters.active.count)

      @contester.contest.update_ranks(@contester, old_rank, new_rank) if old_rank != new_rank
    end

    if @contester.update(Contester.params(params, cuser))
      flash[:notice] = t(:contests_contester_update)
      redirect_to edit_contest_path(@contester.contest_id, anchor: 'teams')
    else
      flash.now[:error] = @contester.errors.full_messages.to_sentence.presence || t(:error)
      render :edit, status: :unprocessable_entity
    end
  end

  def recover
    raise AccessError unless @contester.can_destroy? cuser

    @contester.recover
    flash[:notice] = t(:contests_contester_recovered)
    redirect_to edit_contest_path(@contester.contest_id, anchor: 'teams')
  end

  def destroy
    raise AccessError unless @contester.can_destroy? cuser

    @contester.destroy
    flash[:notice] = t(:contests_contester_destroy)
    redirect_to edit_contest_path(@contester.contest_id, anchor: 'teams')
  end

  private

  def load_contester
    @contester = Contester.find params[:id]
  end
end
