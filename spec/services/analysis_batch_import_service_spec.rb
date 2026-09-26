# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalysisBatchImportService do
  let(:batch_id) { 42 }
  let(:exports_dir) { Dir.mktmpdir('analysis-import-spec') }
  let(:service) { described_class.new(batch_id, exports_dir: exports_dir) }

  after do
    FileUtils.remove_entry(exports_dir) if File.directory?(exports_dir)
  end

  describe '#call' do
    it 'rejects a batch with no analytical exports' do
      expect { service.call }.to raise_error(described_class::Error, /No recognized analysis exports/)
    end
  end

  describe '#analysis_sources' do
    it 'includes all non-raw Parquet directories and excludes raw round/log input' do
      %w[scenario_metrics tech_metrics rounds log_lines].each do |dataset|
        directory = File.join(exports_dir, batch_id.to_s, dataset)
        FileUtils.mkdir_p(directory)
        File.write(File.join(directory, 'part-0.parquet'), 'content')
      end

      expect(service.send(:analysis_sources).map(&:first)).to eq(%w[scenario_metrics tech_metrics])
    end
  end

  describe '#identity_fields_for' do
    it 'uses structural fields for known relations and every field as a forward-compatible fallback' do
      expect(service.send(:identity_fields_for, 'scenario_metrics', %w[metric round_count kill_rate]))
        .to eq(%w[metric kill_rate])
      expect(service.send(:identity_fields_for, 'future_analysis', %w[foo bar])).to eq(%w[foo bar])
    end
  end

  describe '#existing_glob' do
    it 'returns a glob when Parquet files exist in the subdirectory' do
      directory = File.join(exports_dir, batch_id.to_s, 'metrics')
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, 'part-1.parquet'), 'content')

      expect(service.send(:existing_glob, 'metrics')).to eq(File.join(directory, '*.parquet'))
    end

    it 'returns nil when a subdirectory is missing or has no Parquet files' do
      expect(service.send(:existing_glob, 'missing')).to be_nil
    end

    it 'rejects a batch directory that escapes the exports directory' do
      allow(service).to receive(:batch_dir).and_return('/tmp/not-under-root/42')

      expect { service.send(:existing_glob, 'metrics') }.to raise_error(described_class::Error, /escapes/)
    end
  end
end
