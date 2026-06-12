module Citator
  # Parses a document's text for citations to other authorities and creates
  # the corresponding CitingReference edges, inferring treatment from
  # signal verbs near each citation and depth from how often the authority
  # is discussed.
  class EdgeBuilder
    TREATMENT_CUES = {
      overruled: /\boverrul/i,
      reversed: /\brevers/i,
      vacated: /\bvacat/i,
      abrogated: /\babrogat/i,
      superseded: /\bsupersed/i,
      distinguished: /\bdistinguish/i,
      limited: /\blimit(?:ed|ing|s)?\b.{0,40}\b(?:to its facts|holding|reach)/i,
      criticized: /\bcriticiz/i,
      questioned: /\bquestion(?:ed|ing|s)\b/i,
      called_into_doubt: /\b(?:doubt|call(?:ed|s)? into question)/i,
      followed: /\bfollow(?:ed|ing|s)?\b/i,
      affirmed: /\baffirm/i,
      explained: /\bexplain/i,
      cited_favorably: /\b(?:agree(?:d|ing)? with|adopt(?:ed|ing)?|persuasive|reaffirm)/i
    }.freeze

    CUE_WINDOW = 220

    def initialize(document)
      @document = document
    end

    def run!
      text = @document.reading_text
      return [] if text.blank?

      found = Citations::Extractor.parse(text)
      grouped = group_by_authority(found)

      edges = grouped.filter_map do |normalized, occurrences|
        target = Citation.find_by(normalized:)&.document
        next if target.nil? || target.id == @document.id

        build_edge(target, occurrences, text)
      end
      edges
    end

    private

    def group_by_authority(found)
      found.each_with_object(Hash.new { |h, k| h[k] = [] }) do |f, groups|
        key = f.normalized || f.resolved_from&.normalized
        groups[key] << f if key.present?
      end
    end

    def build_edge(target, occurrences, text)
      treatment = infer_treatment(occurrences, text)
      depth = infer_depth(occurrences.size)
      first = occurrences.first

      edge = CitingReference.find_or_initialize_by(citing_document: @document, cited_document: target)
      edge.assign_attributes(
        treatment:,
        depth:,
        pin_cite: first.pin_cite,
        passage: passage_around(text, first.position)
      )
      edge.save!
      edge
    end

    def infer_treatment(occurrences, text)
      occurrences.each do |occurrence|
        window = window_around(text, occurrence.position)
        TREATMENT_CUES.each do |treatment, cue|
          return treatment if cue.match?(window)
        end
      end
      :cited
    end

    def infer_depth(count)
      case count
      when 1 then :passing
      when 2..3 then :discussed
      when 4..5 then :significant
      else :extended
      end
    end

    def window_around(text, position)
      from = [position - CUE_WINDOW, 0].max
      text[from, CUE_WINDOW + 80].to_s
    end

    def passage_around(text, position)
      from = [position - 120, 0].max
      text[from, 360].to_s.squish
    end
  end
end
