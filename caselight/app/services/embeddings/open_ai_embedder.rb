module Embeddings
  # Hosted embeddings via the OpenAI embeddings endpoint. Uses the
  # `dimensions` reduction parameter so stored vectors match the schema.
  class OpenAiEmbedder
    ENDPOINT = URI("https://api.openai.com/v1/embeddings")
    MODEL = ENV.fetch("EMBEDDINGS_OPENAI_MODEL", "text-embedding-3-small")

    def embed(text)
      embed_batch([text]).first
    end

    def embed_batch(texts)
      api_key = ENV["OPENAI_API_KEY"]
      raise "OPENAI_API_KEY is required for EMBEDDINGS_PROVIDER=openai" if api_key.blank?

      response = Net::HTTP.post(
        ENDPOINT,
        { model: MODEL, input: texts, dimensions: Embeddings.dimensions }.to_json,
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      )
      raise "OpenAI embeddings error #{response.code}: #{response.body.truncate(200)}" unless response.code.to_i == 200

      JSON.parse(response.body).fetch("data").sort_by { |d| d["index"] }.map { |d| d["embedding"] }
    end
  end
end
