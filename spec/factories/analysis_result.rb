# frozen_string_literal: true

FactoryBot.define do
  factory :analysis_result do
    batch_id { 1 }
    steamid { '0:1:12345' }
    model { 'os' }
    metric { 'skill' }
    value { 25.0 }
    milestone { AnalysisResult::NO_MILESTONE }
  end
end
