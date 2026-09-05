# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoundBatchImportJob do
  describe '#perform' do
    it 'delegates to RoundBatchImportService with the provided batch id' do
      service = instance_double(RoundBatchImportService, call: { rounds: 1 })
      expect(RoundBatchImportService).to receive(:new).with(42).and_return(service)

      described_class.new.perform(42)

      expect(service).to have_received(:call)
    end
  end
end
