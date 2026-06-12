module Search
  # Layer 2: Postgres full-text search over the documents.search_vector
  # tsvector column. Acts as the always-available fallback engine and the
  # source of truth for exact-match lookups.
  class PostgresAdapter
    Hit = Struct.new(:document_id, :score, :snippet, keyword_init: true)

    HEADLINE_OPTS = "StartSel=<mark>, StopSel=</mark>, MaxWords=22, MinWords=10, " \
                    "MaxFragments=2, FragmentDelimiter=\" … \"".freeze

    def initialize(scope: Document.all)
      @scope = scope
    end

    # mode: :natural (websearch syntax) or :boolean (terms-and-connectors).
    def search(query:, mode: :natural, sort: "relevance", page: 1, per: 20)
      ts = ts_expression(query, mode)
      rel = @scope.where("documents.search_vector @@ #{ts}")
      total = rel.count(:id)
      ids_with_rank = rel.reorder(Arel.sql(order_sql(ts, sort)))
                         .offset((page - 1) * per).limit(per)
                         .pluck(:id, Arel.sql("ts_rank_cd(documents.search_vector, #{ts}, 32)"))
      snippets = snippets_for(ids_with_rank.map(&:first), ts)
      hits = ids_with_rank.map do |id, rank|
        Hit.new(document_id: id, score: rank.to_f, snippet: snippets[id])
      end
      { hits:, total: }
    rescue ActiveRecord::StatementInvalid
      # Unparseable boolean syntax: degrade to plain matching.
      mode == :boolean ? search(query: strip_operators(query), mode: :natural, sort:, page:, per:) : { hits: [], total: 0 }
    end

    # Ranked candidate ids for hybrid fusion.
    def ranked_ids(query:, mode: :natural, limit: 150)
      ts = ts_expression(query, mode)
      @scope.where("documents.search_vector @@ #{ts}")
            .reorder(Arel.sql(order_sql(ts, "relevance")))
            .limit(limit)
            .pluck(:id)
    rescue ActiveRecord::StatementInvalid
      []
    end

    def matching_scope(query:, mode: :natural)
      @scope.where("documents.search_vector @@ #{ts_expression(query, mode)}")
    end

    def snippets_for(ids, ts)
      return {} if ids.empty?

      rows = Document.connection.select_rows(<<~SQL)
        SELECT id, ts_headline('english',
                               left(coalesce(full_text, summary, title, ''), 60000),
                               #{ts}, '#{HEADLINE_OPTS}')
        FROM documents WHERE id IN (#{ids.map(&:to_i).join(',')})
      SQL
      rows.to_h
    end

    def ts_expression(query, mode)
      conn = Document.connection
      if mode == :boolean
        "to_tsquery('english', #{conn.quote(BooleanTranslator.to_tsquery(query))})"
      else
        "websearch_to_tsquery('english', #{conn.quote(query)})"
      end
    end

    # Facet counts computed in SQL when OpenSearch aggregations are not
    # available. Returns { dimension => { key => count } }.
    def self.facet_counts(scope)
      {
        jurisdictions: scope.where.not(jurisdiction_id: nil).group(:jurisdiction_id).count,
        court_levels: scope.joins(:court).group("courts.level").count,
        doc_types: scope.group(:type).count,
        practice_areas: scope.where.not(practice_area: nil).group(:practice_area).count,
        topics: scope.where.not(primary_topic_id: nil).group(:primary_topic_id)
                     .order(Arel.sql("count(*) DESC")).limit(12).count,
        judges: scope.where.not(author_judge_id: nil).group(:author_judge_id)
                     .order(Arel.sql("count(*) DESC")).limit(12).count,
        treatments: scope.group(:treatment_status).count
      }
    end

    private

    def order_sql(ts, sort)
      case sort
      when "date" then "documents.decided_on DESC NULLS LAST, documents.id DESC"
      when "cited" then "documents.cited_by_count DESC, documents.id DESC"
      else "ts_rank_cd(documents.search_vector, #{ts}, 32) DESC, documents.cited_by_count DESC, documents.id DESC"
      end
    end

    def strip_operators(query)
      query.gsub(/[!*"()&|%]|\b(AND|OR|NOT)\b|\/(s|p|\d+)/, " ").squeeze(" ").strip
    end
  end
end
