# frozen_string_literal: true

namespace :db do
  desc 'Truncate all data imported from ensl_analysis parquet export batches'
  task truncate_parquet_imports: :environment do
    tables = %w[log_lines rounders log_files rounds analysis_results]

    ActiveRecord::Base.connection.truncate_tables(*tables)
    puts "Truncated parquet-imported tables: #{tables.join(', ')}"
  end
end
