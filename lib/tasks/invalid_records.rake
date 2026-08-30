# frozen_string_literal: true

namespace :db do
  desc 'Summarize invalid database rows by model and validation error signature without dumping raw records.'
  task :invalid_summary, %i[models limit] => :environment do |_task, args|
    model_names = args[:models].to_s.split(',').map(&:strip).reject(&:empty?)
    limit = args[:limit].to_i
    limit = 20 if limit <= 0

    summary = InvalidRecordSummary.call(model_names: model_names.presence, limit: limit)
    puts InvalidRecordSummary.new.format(summary)
  end
end
