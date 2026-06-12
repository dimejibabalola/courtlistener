module Ai
  module Clients
    # Deterministic extractive answerer used when no hosted provider is
    # configured. It never generates text of its own: it selects and stitches
    # the most relevant sentences from the supplied sources, so every claim
    # is verbatim from a citable passage.
    class LocalClient
      SOURCE_BLOCK = /<source n="(\d+)"[^>]*>(.*?)<\/source>/m

      def complete(system:, user:, model: nil, max_tokens: nil)
        question = user[/<question>(.*?)<\/question>/m, 1] || user
        sources = user.scan(SOURCE_BLOCK)
        return fallback_answer if sources.empty?

        terms = significant_terms(question)
        picks = best_sentences(sources, terms)
        return fallback_answer if picks.empty?

        body = picks.map { |sentence, n| "#{sentence.strip} [#{n}]" }.join(" ")
        "Based on the sources retrieved for this question: #{body}"
      end

      private

      def significant_terms(question)
        question.downcase.scan(/[a-z][a-z']{3,}/) - %w[what when where which whose does should could would about court case under]
      end

      def best_sentences(sources, terms)
        scored = []
        sources.each do |n, text|
          text.split(/(?<=[.!?])\s+/).each do |sentence|
            next if sentence.length < 40 || sentence.length > 400

            words = sentence.downcase
            score = terms.count { |t| words.include?(t) }
            scored << [score, sentence.squish, n] if score.positive?
          end
        end
        scored.sort_by! { |score, sentence, _| [-score, sentence.length] }
        picked = []
        scored.each do |_, sentence, n|
          next if picked.any? { |s, _| s == sentence }

          picked << [sentence, n]
          break if picked.size >= 3
        end
        picked
      end

      def fallback_answer
        "I could not find support for this question in the available sources. " \
          "Try rephrasing, broadening the search scope, or configuring a hosted " \
          "model provider in Settings for deeper synthesis."
      end
    end
  end
end
