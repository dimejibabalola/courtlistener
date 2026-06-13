# Embedding provider registry. Defaults to the deterministic offline hash
# embedder so the demo works with no setup; set EMBEDDINGS_PROVIDER=service
# (real semantic search via the embedding microservice — bge-small-en-v1.5 or
# Qwen3-Embedding-0.6B) or =openai, and re-embed the corpus. All providers must
# emit vectors of Embeddings.dimensions.
module Embeddings
  def self.dimensions
    Rails.configuration.x.embedding_dimensions
  end

  def self.embedder
    @embedder ||= build(ENV.fetch("EMBEDDINGS_PROVIDER", "hash"))
  end

  def self.build(provider)
    case provider
    when "service", "qwen" then ServiceEmbedder.new
    when "openai" then OpenAiEmbedder.new
    else HashEmbedder.new
    end
  end

  def self.reset!
    @embedder = nil
  end
end
