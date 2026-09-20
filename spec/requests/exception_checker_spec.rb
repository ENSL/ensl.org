# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Exception checker', order: :defined, type: :request do
  it 'detects logged exceptions', :expect_log_error do
    # Intentionally append a matching error line without failing the example itself.
    log_file = Rails.root.join('log/test.log')
    FileUtils.mkdir_p(log_file.dirname)
    File.open(log_file, 'a') do |file|
      file.puts('ERROR -- : NoMethodError: exception checker test')
    end

    expect(log_file.read).to include('NoMethodError: exception checker test')
  end

  it 'ignores old log errors from previous tests' do
    # Should not fail: no new log entries are written in this example.
    expect { assert_no_log_errors }.not_to raise_error
  end

  it 'ignores messages processed after a WebSocket closes' do
    log_file = Rails.root.join('log/test.log')
    File.open(log_file, 'a') do |file|
      file.puts('ERROR -- : Ignoring message processed after the WebSocket was closed: subscription')
    end

    expect { assert_no_log_errors }.not_to raise_error
  end
end
