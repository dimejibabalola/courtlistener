namespace :embeddings do
  desc "Re-embed every document and headnote synchronously with the configured embedder"
  task reindex: :environment do
    total = Document.count
    puts "Re-embedding #{total} documents via #{Embeddings.embedder.class.name} (#{Embeddings.dimensions}-dim)..."
    Document.find_each.with_index do |document, i|
      Search::Indexer.new(document).run!
      print "\r  #{i + 1}/#{total}" if ((i + 1) % 5).zero? || i + 1 == total
    end
    puts "\nDone."
  end

  # Called from the container entrypoint after migrations: if embeddings are
  # missing (e.g. just widened to 1024 dims), enqueue background re-indexing on
  # the worker, which can reach the embedding service over the private network.
  desc "Enqueue re-indexing when stored embeddings are missing"
  task enqueue_if_stale: :environment do
    next if Document.none?

    stale = Document.where.missing(:chunks).exists? ||
            DocumentChunk.where(embedding: nil).exists? ||
            Headnote.where(embedding: nil).exists?
    next unless stale

    count = 0
    Document.find_each do |document|
      IndexDocumentJob.perform_later(document.id)
      count += 1
    end
    puts "Enqueued re-indexing for #{count} documents (embeddings were stale)."
  end
end
