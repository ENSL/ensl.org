# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Exception checker', type: :request, order: :defined do
  it 'detects logged exceptions', :expect_log_error do
    # Intentionally append a matching error line without failing the example itself.
    log_file = Rails.root.join('log', 'test.log')
    FileUtils.mkdir_p(log_file.dirname)
    File.open(log_file, 'a') do |file|
      file.puts('ERROR -- : NoMethodError: exception checker test')
    end
    expect(true).to be(true)
  end

  it 'ignores old log errors from previous tests' do
    # Should not fail: no new log entries are written in this example.
    expect(true).to be(true)
  end
end
