# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Zeitwerk compliance' do
  it 'eager loads all files without Zeitwerk naming errors' do
    expect { Zeitwerk::Loader.eager_load_all }.not_to raise_error
  end
end
