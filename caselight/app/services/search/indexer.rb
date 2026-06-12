module Search
  # Per-document indexing: rebuilds passage chunks + embeddings (pgvector),
  # embeds headnotes, and pushes to OpenSearch when a cluster is reachable.
  # The tsvector layer maintains itself via database trigger.
  class Indexer
    CHUNK_CHARS = 1100
    MIN_TAIL = 200

    def self.chunk_text(text)
      paragraphs = text.to_s.split(/\n{2,}/).map(&:strip).reject(&:blank?)
      chunks = []
      buffer = +""
      paragraphs.each do |paragraph|
        if buffer.length + paragraph.length + 2 > CHUNK_CHARS && buffer.present?
          chunks << buffer.dup
          buffer.clear
        end
        # Hard-split paragraphs that alone exceed the window.
        while paragraph.length > CHUNK_CHARS
          split_at = paragraph.rindex(/[.;]\s/, CHUNK_CHARS) || CHUNK_CHARS
          chunks << (buffer + paragraph[0..split_at]).strip
          buffer.clear
          paragraph = paragraph[(split_at + 1)..].to_s.strip
        end
        buffer << (buffer.empty? ? paragraph : "\n\n#{paragraph}")
      end
      chunks << buffer.strip if buffer.strip.length >= MIN_TAIL || (chunks.empty? && buffer.present?)
      chunks
    end

    def initialize(document)
      @document = document
    end

    def run!
      rebuild_chunks!
      embed_headnotes!
      push_to_opensearch!
      @document
    end

    def rebuild_chunks!
      texts = self.class.chunk_text(@document.reading_text)
      vectors = Embeddings.embedder.embed_batch(texts)
      @document.chunks.delete_all
      texts.each_with_index do |content, position|
        @document.chunks.create!(content:, position:, embedding: vectors[position])
      end
    end

    def embed_headnotes!
      pending = @document.headnotes.where(embedding: nil)
      return if pending.none?

      vectors = Embeddings.embedder.embed_batch(pending.map(&:text))
      pending.each_with_index { |headnote, i| headnote.update!(embedding: vectors[i]) }
    end

    def push_to_opensearch!
      return unless OpenSearchAdapter.available?

      OpenSearchAdapter.ensure_index!
      OpenSearchAdapter.index_document(@document)
    end
  end
end
