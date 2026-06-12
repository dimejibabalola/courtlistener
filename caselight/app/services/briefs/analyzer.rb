module Briefs
  # Brief-to-authority checking: parses every citation out of an uploaded
  # brief, resolves short forms, matches each authority to the corpus, and
  # snapshots its current treatment so the user can see at a glance whether
  # the brief relies on bad law.
  class Analyzer
    CONTEXT_WINDOW = 240

    def initialize(analysis)
      @analysis = analysis
      @brief = analysis.uploaded_document
    end

    def run!
      @analysis.update!(status: :processing, started_at: Time.current)
      text = @brief.extracted_text
      raise "brief has no extracted text" if text.blank?

      @analysis.brief_citations.delete_all
      found = Citations::Extractor.parse(text)
      records = {}

      found.each_with_index do |f, index|
        match = Citations::Matcher.match(f)
        records[f] = @analysis.brief_citations.create!(
          position: index,
          raw_cite: f.raw,
          normalized_cite: f.normalized || f.resolved_from&.normalized,
          kind: f.kind,
          pin_cite: f.pin_cite,
          context: context_around(text, f.position),
          document: match.document,
          status: match.status,
          treatment_status: match.document&.treatment_status || :untreated,
          resolved_from: records[f.resolved_from]
        )
      end

      @analysis.refresh_counts!
      @analysis.update!(status: :complete, completed_at: Time.current)
      @analysis
    rescue StandardError => e
      @analysis.update!(status: :failed, error_message: e.message.truncate(250))
      raise
    end

    private

    def context_around(text, position)
      from = [position - CONTEXT_WINDOW / 2, 0].max
      text[from, CONTEXT_WINDOW + 60].to_s.squish
    end
  end
end
