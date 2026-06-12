module Search
  # Translates terms-and-connectors syntax into the two execution targets:
  #
  #   to_tsquery        -> Postgres tsquery string (fallback engine)
  #   to_query_string   -> OpenSearch query_string syntax
  #
  # Supported: AND, OR, NOT/%, "phrase", ( ) grouping, ! root expander,
  # * wildcard, /n within-n-words, /s same-sentence, /p same-paragraph.
  #
  # Proximity caveats: Postgres tsquery has no within-N operator, so /n, /s
  # and /p degrade to AND in the fallback engine. OpenSearch approximates
  # them as phrase-with-slop (~n, ~12, ~75 respectively). Adjacent bare
  # terms are implicitly ANDed.
  class BooleanTranslator
    TOKEN = /"[^"]*"|\(|\)|\/\d+|\/[sp]\b|AND\b|OR\b|NOT\b|&|\||%|[^\s()|&]+/
    PROXIMITY_SLOP = { "/s" => 12, "/p" => 75 }.freeze

    def self.to_tsquery(query) = new(query).to_tsquery
    def self.to_query_string(query) = new(query).to_query_string

    def initialize(query)
      @tokens = query.to_s.scan(TOKEN)
    end

    def to_tsquery
      out = []
      @tokens.each do |token|
        case token
        when "(", ")" then out << token
        when "AND", "&" then out << "&"
        when "OR", "|" then out << "|"
        when "NOT", "%" then out << "& !"
        when %r{\A/} then out << "&" # proximity degrades to AND in tsquery
        when /\A"(.*)"\z/m then out << phrase_to_tsquery(Regexp.last_match(1))
        else out << term_to_tsquery(token)
        end
      end
      join_with_implicit(out, "&").gsub("& & !", "& !")
    end

    def to_query_string
      out = []
      pending_proximity = nil
      @tokens.each do |token|
        case token
        when "(", ")" then out << token
        when "AND", "&" then out << "AND"
        when "OR", "|" then out << "OR"
        when "NOT", "%" then out << "NOT"
        when %r{\A/(\d+)\z} then pending_proximity = Regexp.last_match(1).to_i
        when %r{\A/[sp]\z} then pending_proximity = PROXIMITY_SLOP[token]
        when /\A"(.*)"\z/m then out << append_proximity(%("#{Regexp.last_match(1)}"), pending_proximity).tap { pending_proximity = nil }
        else
          term = token.sub(/!\z/, "*") # root expander -> prefix wildcard
          if pending_proximity && out.last && out.last !~ /\A(AND|OR|NOT|\()\z/
            prev = out.pop.delete('"*')
            out << %("#{prev} #{term.delete('*')}"~#{pending_proximity})
            pending_proximity = nil
          else
            out << term
          end
        end
      end
      join_with_implicit(out, "AND")
    end

    private

    def term_to_tsquery(token)
      if token.end_with?("!")
        "#{sanitize(token.chomp('!'))}:*"
      elsif token.include?("*")
        # tsquery only supports prefix matching; take the stem before *.
        "#{sanitize(token.split('*').first)}:*"
      else
        sanitize(token)
      end
    end

    def phrase_to_tsquery(phrase)
      words = phrase.split.map { |w| sanitize(w) }.reject(&:blank?)
      return "" if words.empty?

      "(#{words.join(' <-> ')})"
    end

    def append_proximity(quoted, slop)
      slop ? "#{quoted}~#{slop}" : quoted
    end

    def sanitize(word)
      word.gsub(/['&|!():*<>\\]/, "").strip
    end

    # Insert the implicit operator between two adjacent operands.
    def join_with_implicit(tokens, op)
      result = []
      tokens.each do |token|
        if result.any? && operand_end?(result.last) && operand_start?(token, op)
          result << op
        end
        result << token
      end
      result.reject(&:blank?).join(" ").squeeze(" ").strip
    end

    def operand_end?(token)
      !%w[& | AND OR NOT % (].include?(token) && token != "& !" && !token.end_with?("(")
    end

    def operand_start?(token, op)
      !%w[& | AND OR NOT % )].include?(token) && token != "& !" && !(op == "&" && token.start_with?("!"))
    end
  end
end
