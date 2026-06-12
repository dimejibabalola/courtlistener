module Search
  # Classifies a raw query and decides which engine(s) answer it:
  #
  #   citation -> direct Postgres lookup of the normalized citation
  #   boolean  -> terms-and-connectors, OpenSearch (PG tsquery fallback)
  #   natural  -> hybrid lexical BM25 + pgvector cosine, fused with RRF
  class QueryPlanner
    Plan = Struct.new(:query, :strategy, :reason, keyword_init: true)

    # Case-sensitive operator words per terms-and-connectors convention, so
    # prose like "piercing the veil and fraud" stays natural language.
    CONNECTOR_RES = [
      /(?:^|\s)(?:AND|OR|NOT)(?:\s|$)/,
      /(?:^|\s)[&|%](?:\s|$)/,
      %r{/(?:s|p|\d+)(?:\s|$)},      # /s /p /n proximity
      /\w!(?:\s|$)/,                  # root expander: litigat!
      /\w\*/,                         # wildcard: wom*n, judg*
      /"[^"]+"/                       # exact phrase
    ].freeze

    def self.plan(query) = new(query).plan

    def initialize(query)
      @query = query.to_s.strip
    end

    def plan
      return Plan.new(query: @query, strategy: :natural, reason: "empty query") if @query.blank?

      if Citations::Parser.citation_query?(@query)
        Plan.new(query: @query, strategy: :citation, reason: "recognized citation pattern")
      elsif connectors?
        Plan.new(query: @query, strategy: :boolean, reason: "terms-and-connectors operators present")
      else
        Plan.new(query: @query, strategy: :natural, reason: "natural-language query")
      end
    end

    private

    def connectors?
      CONNECTOR_RES.any? { |re| re.match?(@query) }
    end
  end
end
