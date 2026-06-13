module Embeddings
  # Client for the embedding microservice (see embedding_service/), which runs a
  # sentence-transformers model — bge-small-en-v1.5 by default, or
  # Qwen3-Embedding-0.6B on a larger host. Search queries are encoded with the
  # model's retrieval instruction; documents plain (asymmetric retrieval). The
  # service owns the model; this client just validates the returned dimension.
  class ServiceEmbedder
    DEFAULT_URL = "http://localhost:8000".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 120 # the first call after a cold start pays model load time

    # Query path. Fails soft (nil) so a slow/unavailable service degrades search
    # to lexical-only rather than erroring the page.
    def embed(text)
      request([text.to_s], mode: "query")&.first
    rescue StandardError => e
      Rails.logger.warn("[ServiceEmbedder] query embed failed: #{e.class}: #{e.message}")
      nil
    end

    # Document path (indexing). Raises on failure so the enqueuing job retries.
    def embed_batch(texts)
      request(texts.map(&:to_s), mode: "document")
    end

    private

    def request(texts, mode:)
      return [] if texts.empty?

      uri = URI.join(base_url, "/embed")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      req.body = { texts:, mode: }.to_json
      response = http.request(req)
      unless response.is_a?(Net::HTTPSuccess)
        raise "embedding service #{response.code}: #{response.body.to_s.truncate(200)}"
      end

      payload = JSON.parse(response.body)
      dim = payload["dim"].to_i
      if dim != Embeddings.dimensions
        raise "embedding dim mismatch: service=#{dim} app=#{Embeddings.dimensions}"
      end

      payload.fetch("embeddings")
    end

    def base_url
      ENV["EMBEDDINGS_URL"].presence || DEFAULT_URL
    end
  end
end
