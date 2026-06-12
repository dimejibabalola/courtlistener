# Embedding provider registry. Defaults to the deterministic offline hash
# embedder so the demo works with no API keys; set EMBEDDINGS_PROVIDER=openai
# (and re-embed the corpus) to use a hosted model. All providers must emit
# vectors of Embeddings.dimensions.
module Embeddings
  def self.dimensions
    Rails.configuration.x.embedding_dimensions
  end

  def self.embedder
    @embedder ||= build(ENV.fetch("EMBEDDINGS_PROVIDER", "hash"))
  end

  def self.build(provider)
    case provider
    when "openai" then OpenAiEmbedder.new
    else HashEmbedder.new
    end
  end

  def self.reset!
    @embedder = nil
  end
end
