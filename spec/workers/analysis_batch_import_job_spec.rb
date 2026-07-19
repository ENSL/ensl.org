# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalysisBatchImportJob do
  describe '#perform' do
    it 'delegates to AnalysisBatchImportService with the provided batch id' do
      service = instance_double(AnalysisBatchImportService, call: 123)
      expect(AnalysisBatchImportService).to receive(:new).with(42).and_return(service)

      described_class.new.perform(42)

      expect(service).to have_received(:call)
    end
  end
end
