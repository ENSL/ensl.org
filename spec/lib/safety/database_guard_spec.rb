# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe Safety::DatabaseGuard do
  describe '.abort_if_dangerous_db_task!' do
    it 'aborts destructive db tasks in development by default' do
      output = StringIO.new

      expect do
        described_class.abort_if_dangerous_db_task!(
          argv: ['db:drop'],
          env: { 'RAILS_ENV' => 'development' },
          output: output
        )
      end.to raise_error(SystemExit)

      expect(output.string).to include('Blocked potentially destructive db task')
      expect(output.string).to include('db:drop')
    end

    it 'allows non-dangerous db tasks' do
      output = StringIO.new

      expect do
        described_class.abort_if_dangerous_db_task!(
          argv: ['db:migrate'],
          env: { 'RAILS_ENV' => 'development' },
          output: output
        )
      end.not_to raise_error
    end

    it 'allows destructive tasks outside development' do
      expect do
        described_class.abort_if_dangerous_db_task!(
          argv: ['db:drop'],
          env: { 'RAILS_ENV' => 'test' },
          output: StringIO.new
        )
      end.not_to raise_error
    end

    it 'allows destructive tasks in development when explicitly opted in' do
      expect do
        described_class.abort_if_dangerous_db_task!(
          argv: ['db:drop'],
          env: { 'RAILS_ENV' => 'development', 'ALLOW_DESTRUCTIVE_DB_TASKS' => '1' },
          output: StringIO.new
        )
      end.not_to raise_error
    end
  end

  describe '.abort_unless_test_env_for_specs!' do
    it 'aborts when environment is not test by default' do
      output = StringIO.new

      expect do
        described_class.abort_unless_test_env_for_specs!(
          env: { 'RAILS_ENV' => 'development' },
          output: output
        )
      end.to raise_error(SystemExit)

      expect(output.string).to include('Blocked specs because RAILS_ENV="development"')
    end

    it 'allows specs in test environment' do
      expect do
        described_class.abort_unless_test_env_for_specs!(
          env: { 'RAILS_ENV' => 'test' },
          output: StringIO.new
        )
      end.not_to raise_error
    end

    it 'allows non-test specs when explicitly opted in' do
      expect do
        described_class.abort_unless_test_env_for_specs!(
          env: { 'RAILS_ENV' => 'development', 'ALLOW_NON_TEST_SPECS' => '1' },
          output: StringIO.new
        )
      end.not_to raise_error
    end
  end

  describe '.abort_if_test_db_matches_development!' do
    it 'aborts when test and development database names are identical' do
      output = StringIO.new
      allow(described_class).to receive(:db_name_for).and_return('ensl_shared_db')
      allow(described_class).to receive(:declared_env_value).and_return('ensl_shared_db')

      expect do
        described_class.abort_if_test_db_matches_development!(output: output)
      end.to raise_error(SystemExit)

      expect(output.string).to include('Unsafe database configuration detected')
      expect(output.string).to include('ensl_shared_db')
    end

    it 'does not abort when names are different' do
      allow(described_class).to receive(:db_name_for).and_return('ensl_test_db')
      allow(described_class).to receive(:declared_env_value).and_return('ensl_dev_db')

      expect do
        described_class.abort_if_test_db_matches_development!(output: StringIO.new)
      end.not_to raise_error
    end
  end
end
