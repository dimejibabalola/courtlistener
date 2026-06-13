# Shared: re-embed every document and headnote synchronously through the
# configured embedder (Search::Indexer rebuilds chunks + embeds, and embeds any
# headnotes whose vector is nil).
def caselight_reembed_all
  total = Document.count
  puts "Re-embedding #{total} documents via #{Embeddings.embedder.class.name} (#{Embeddings.dimensions}-dim)..."
  Document.find_each.with_index do |document, i|
    Search::Indexer.new(document).run!
    print "\r  #{i + 1}/#{total}" if ((i + 1) % 5).zero? || i + 1 == total
  end
  puts "\nDone."
end

namespace :embeddings do
  desc "Re-embed every document and headnote with the configured embedder"
  task reindex: :environment do
    caselight_reembed_all
  end

  # Run from the container entrypoint after migrations. Re-embeds inline when
  # stored vectors are missing/stale (e.g. just after a dimension change). It's
  # synchronous on purpose: the :async adapter is in-process, so jobs enqueued
  # from a one-off process would be lost. A no-op once embeddings are present.
  desc "Re-embed only when stored vectors are missing/stale"
  task reindex_if_stale: :environment do
    next if Document.none?

    stale = Document.where.missing(:chunks).exists? ||
            DocumentChunk.where(embedding: nil).exists? ||
            Headnote.where(embedding: nil).exists?
    next unless stale

    puts "Stored embeddings are stale — re-embedding inline."
    caselight_reembed_all
  end
end
