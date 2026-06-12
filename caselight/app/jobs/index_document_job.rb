# Re-index a single document (chunks, embeddings, OpenSearch) without
# rebuilding citation edges.
class IndexDocumentJob < ApplicationJob
  queue_as :indexing

  def perform(document_id)
    document = Document.find_by(id: document_id)
    return if document.nil?

    Search::Indexer.new(document).run!
  end
end
