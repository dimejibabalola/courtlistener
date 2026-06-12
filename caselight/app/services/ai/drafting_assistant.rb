module Ai
  # Generates a draft paragraph about an authority, in the requested tone,
  # grounded in that document's own summary/holding. The local provider
  # composes from the document's fields; hosted providers rewrite with tone.
  class DraftingAssistant
    TONES = {
      "neutral" => "an objective, neutral tone",
      "persuasive" => "a persuasive advocate's tone",
      "formal" => "a formal, traditional brief-writing tone",
      "plain" => "plain English for a client audience"
    }.freeze

    def initialize(user)
      @user = user
    end

    def paragraph_for(document, tone: "neutral")
      base = compose_locally(document)
      provider, model = Providers.resolve(@user)
      return base if provider == "local"

      Providers.client_for(provider, user: @user).complete(
        system: "You rewrite legal drafting passages. Preserve all citations exactly. " \
                "Do not add authorities or facts not present in the input.",
        user: "Rewrite in #{TONES.fetch(tone, TONES['neutral'])}:\n\n#{base}",
        model: model,
        max_tokens: 1024
      )
    rescue Ai::ProviderError
      base
    end

    private

    def compose_locally(document)
      court = document.court&.short_name
      cite = document.display_citation
      pieces = []
      pieces << "The #{court || 'court'} has #{verb_for(document)} #{summary_clause(document)}"
      pieces << "#{document.title}, #{cite}#{document.decided_on ? " (#{paren_court(document)}#{document.decided_on.year})" : ''}."
      pieces.join(" ")
    end

    def verb_for(document)
      document.holding.present? ? "held" : "recognized"
    end

    def summary_clause(document)
      clause = document.holding.presence || document.summary.presence || "the principle at issue"
      clause = clause.split(/(?<=[.!?])\s/).first.to_s
      "that #{clause.sub(/\A(No\.|Yes\.)\s*/i, '').sub(/\A[A-Z]/) { |c| c.downcase }.chomp('.')}."
    end

    def paren_court(document)
      abbrev = document.court&.abbreviation
      abbrev.present? ? "#{abbrev} " : ""
    end
  end
end
