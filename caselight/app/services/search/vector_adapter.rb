module Search
  # Layer 3: pgvector cosine similarity over document chunks and headnotes,
  # for natural-language queries and "more like this".
  class VectorAdapter
    Hit = Struct.new(:document_id, :distance, :content, keyword_init: true)

    POOL = 80

    # Returns hits ordered best-first, at most one per document.
    def search(query, scope_ids: nil, limit: POOL)
      embedding = Embeddings.embedder.embed(query)
      return [] if embedding.blank?

      nearest(embedding, scope_ids:, limit:)
    end

    def more_like(document, limit: 10)
      seed = document.chunks.embedded.first || document.headnotes.embedded.first
      return [] if seed.nil?

      nearest(seed.embedding.to_a, limit: limit + 1)
        .reject { |hit| hit.document_id == document.id }
        .first(limit)
    end

    private

    def nearest(embedding, scope_ids: nil, limit: POOL)
      chunk_rel = DocumentChunk.embedded.nearest_neighbors(:embedding, embedding, distance: "cosine").limit(limit)
      headnote_rel = Headnote.embedded.nearest_neighbors(:embedding, embedding, distance: "cosine").limit(limit)
      if scope_ids
        chunk_rel = chunk_rel.where(document_id: scope_ids)
        headnote_rel = headnote_rel.where(document_id: scope_ids)
      end

      best = {}
      (chunk_rel.to_a + headnote_rel.to_a).each do |row|
        content = row.is_a?(Headnote) ? row.text : row.content
        hit = Hit.new(document_id: row.document_id, distance: row.neighbor_distance, content:)
        current = best[hit.document_id]
        best[hit.document_id] = hit if current.nil? || hit.distance < current.distance
      end
      best.values.sort_by(&:distance).first(limit)
    end
  end
end
