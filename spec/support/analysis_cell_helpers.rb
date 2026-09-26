# frozen_string_literal: true

module AnalysisCellHelpers
  def create_analysis_row(batch_id:, model:, values:, digest: SecureRandom.random_bytes(16))
    values.each do |field, source_value|
      numeric = source_value.is_a?(Numeric)
      AnalysisResult.create!(batch_id: batch_id, model: model, digest: digest, field: field,
                             value: numeric ? source_value.to_f : nil,
                             text_value: numeric ? nil : source_value.to_s)
    end
    digest
  end

  def create_analysis_user(batch_id:, user_id:, steam_id:, **values)
    create_analysis_row(batch_id: batch_id, model: 'users',
                        values: { 'id' => user_id, 'steam_id' => steam_id }.merge(values.transform_keys(&:to_s)))
  end

  def create_analysis_skill(batch_id:, model:, user_id:, skill:)
    create_analysis_row(batch_id: batch_id, model: model,
                        values: { 'user_id' => user_id, "skill_#{model}" => skill })
  end

  def create_analysis_class_stat(batch_id:, user_id:, class_name:, **values)
    create_analysis_row(batch_id: batch_id, model: 'class_stats',
                        values: { 'user_id' => user_id, 'class_name' => class_name }.merge(values.transform_keys(&:to_s)))
  end

  def create_analysis_skill_for_user(batch_id:, user:, model:, skill:, source_steam_id: user.steamid)
    create_analysis_user(batch_id: batch_id, user_id: user.id, steam_id: source_steam_id)
    create_analysis_skill(batch_id: batch_id, model: model, user_id: user.id, skill: skill)
  end
end

RSpec.configure do |config|
  config.include AnalysisCellHelpers
end
