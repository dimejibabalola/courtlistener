# Embedding provider registry. Defaults to the deterministic offline hash
# embedder so the demo works with no API keys; set EMBEDDINGS_PROVIDER=qwen
# (real semantic search via the Qwen3-Embedding-0.6B service) or =openai, and
# re-embed the corpus. All providers must emit vectors of Embeddings.dimensions.
module Embeddings
  def self.dimensions
    Rails.configuration.x.embedding_dimensions
  end

  def self.embedder
    @embedder ||= build(ENV.fetch("EMBEDDINGS_PROVIDER", "hash"))
  end

  def self.build(provider)
    case provider
    when "qwen" then QwenEmbedder.new
    when "openai" then OpenAiEmbedder.new
    else HashEmbedder.new
    end
  end

  def self.reset!
    @embedder = nil
  end
end
