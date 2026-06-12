module Citator
  # Incremental treatment recompute for one cited authority; enqueued by
  # CitingReference callbacks and by the ingest pipeline.
  class RecomputeTreatmentJob < ApplicationJob
    queue_as :citator

    def perform(document_id)
      document = Document.find_by(id: document_id)
      return if document.nil?

      TreatmentResolver.new(document).resolve!
      Search::OpenSearchAdapter.index_document(document) if Search::OpenSearchAdapter.available?
    end
  end
end
