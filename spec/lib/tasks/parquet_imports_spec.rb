# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'db:truncate_parquet_imports' do
  before(:all) do
    Rails.application.load_tasks
  end

  after do
    Rake::Task['db:truncate_parquet_imports'].reenable
  end

  it 'truncates every table populated by the parquet batch importers' do
    log_file = LogFile.create!(sha256: 'a' * 64, filename: 'server.log')
    round = Round.create!(server_name: 'server one', start_time: Time.current.change(usec: 0))
    Rounder.create!(round: round, steamid: 'STEAM_0:1:1', team: Rounder::TEAM_MARINES, share: 1.0)
    LogLine.create!(log_file: log_file, round: round, raw_text: 'line', line_digest: 'b' * 64)
    create(:analysis_result)

    Rake::Task['db:truncate_parquet_imports'].invoke

    expect([LogLine, Rounder, LogFile, Round, AnalysisResult].map(&:count)).to all(eq(0))
  end
end
