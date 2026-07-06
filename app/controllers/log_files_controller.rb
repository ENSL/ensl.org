class LogFilesController < ApplicationController
  def index
    LogFile.process
    render text: 'Ok'
  end

  def handle
    LogFile.find(params[:id]).deal
    render text: 'Ok'
  end

  def refresh
    LogFile.unhandled.each do |lf|
      lf.deal
    end
  end

  def fix
    Rounder.find_in_batches(batch_size: 100) do |rounders|
      rounders.each do |r|
        r.team_id = nil
        if r.user and t = Teamer.historic(r.user, r.round.start).first
          r.team_id =  t.team_id
        end
        r.save
      end
    end
  end

  def pix
    Round.all.each do |r|
      r.team1_id = nil
      r.team2_id = nil
      [1, 2].each do |team|
        if s = r.rounders.team(team).stats.first
          r["team#{team}_id"] = s["team_id"]
        end
      end
      r.save
    end
  end
end
