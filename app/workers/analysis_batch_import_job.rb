# frozen_string_literal: true

# Thin Sidekiq wrapper around AnalysisBatchImportService. Business logic
# lives in the service so it stays testable/callable without Sidekiq (e.g.
# from a console) -- see that class for the expected export layout.
class AnalysisBatchImportJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(batch_id)
    AnalysisBatchImportService.new(batch_id).call
  end
end
