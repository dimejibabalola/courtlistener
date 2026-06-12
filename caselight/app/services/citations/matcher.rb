module Citations
  # Resolves a parsed citation (Citations::Parser::Found) to a Document.
  class Matcher
    Result = Struct.new(:document, :status, :confidence, keyword_init: true)

    def self.match(found) = new(found).match

    def initialize(found)
      @found = found
    end

    def match
      if (doc = exact_match)
        return Result.new(document: doc, status: :matched, confidence: 1.0)
      end

      if (doc, score = fuzzy_title_match)
        return Result.new(document: doc, status: :needs_review, confidence: score)
      end

      Result.new(document: nil, status: :unmatched, confidence: 0.0)
    end

    private

    def exact_match
      normalized = @found.normalized || @found.resolved_from&.normalized
      return nil if normalized.blank?

      Citation.find_by(normalized:)&.document
    end

    def fuzzy_title_match
      name = @found.case_name || @found.resolved_from&.case_name
      return nil if name.blank?

      row = Document.connection.select_one(<<~SQL, "citation title match", [name])
        SELECT id, similarity(title, $1) AS score
        FROM documents
        WHERE type = 'Case' AND similarity(title, $1) > 0.45
        ORDER BY score DESC
        LIMIT 1
      SQL
      return nil if row.nil?

      [Document.find(row["id"]), row["score"].to_f]
    end
  end
end
