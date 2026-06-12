# Post-ingest processing: index (OpenSearch + tsvector + pgvector), parse
# citations into edges, recompute treatment for affected authorities.
class IngestDocumentJob < ApplicationJob
  queue_as :ingest

  def perform(document_id)
    document = Document.find_by(id: document_id)
    return if document.nil?

    Ingest::Pipeline.process!(document)
  end
end
