module Embeddings
  # Deterministic feature-hashing embedder: unigram + bigram features hashed
  # into a fixed-dimension signed vector, L2-normalized. No network, no
  # model weights — adequate for demo-scale semantic overlap ranking and
  # exercised by the same code paths a hosted embedding model would use.
  class HashEmbedder
    STOPWORDS = %w[
      a an and are as at be but by for from has have in is it its of on or
      that the this to was were which with
    ].to_set.freeze

    def embed(text)
      embed_batch([text]).first
    end

    def embed_batch(texts)
      texts.map { |text| vectorize(text.to_s) }
    end

    private

    def vectorize(text)
      dim = Embeddings.dimensions
      vector = Array.new(dim, 0.0)
      tokens = text.downcase.scan(/[a-z0-9]+/).reject { |t| STOPWORDS.include?(t) }
      return vector if tokens.empty?

      features = Hash.new(0)
      tokens.each { |t| features[t] += 1 }
      tokens.each_cons(2) { |a, b| features["#{a}_#{b}"] += 1 }

      features.each do |feature, count|
        index = Zlib.crc32(feature) % dim
        sign = Zlib.crc32("sign:#{feature}").odd? ? 1.0 : -1.0
        vector[index] += sign * (1.0 + Math.log(count))
      end

      norm = Math.sqrt(vector.sum { |v| v * v })
      norm.zero? ? vector : vector.map { |v| v / norm }
    end
  end
end
