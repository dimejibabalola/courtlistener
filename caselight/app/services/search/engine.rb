module Search
  # Facade over the three search layers. Plans the query, routes it, blends
  # hybrid results with reciprocal-rank fusion, and assembles facets.
  class Engine
    PER_PAGE = 20
    HYBRID_POOL = 150

    Entry = Struct.new(:document, :score, :snippet, :source, keyword_init: true)
    Results = Struct.new(:query, :query_type, :reason, :entries, :total, :page, :per,
                         :facets, :engines, :sort, :filters, keyword_init: true) do
      def total_pages = [(total.to_f / per).ceil, 1].max
      def empty? = entries.empty?
    end

    def call(q:, filters: {}, page: 1, per: PER_PAGE, sort: "relevance")
      page = [page.to_i, 1].max
      filters = Filters.normalize(filters)
      plan = QueryPlanner.plan(q)

      results =
        case plan.strategy
        when :citation then citation_results(plan, filters, page, per, sort)
        when :boolean then lexical_results(plan, filters, page, per, sort, mode: :boolean)
        else hybrid_results(plan, filters, page, per, sort)
        end
      results.sort = sort
      results.filters = filters
      results
    end

    private

    def scope(filters)
      Filters.apply(Document.all, filters)
    end

    # --- Strategy: direct citation fetch (Postgres is source of truth) -----

    def citation_results(plan, filters, page, per, sort)
      document = Document.find_by_citation(plan.query)
      if document.nil?
        fallback = hybrid_results(plan, filters, page, per, sort)
        fallback.query_type = "citation"
        fallback.reason = "no exact citation match; showing closest results"
        return fallback
      end

      entry = Entry.new(document:, score: 1.0,
                        snippet: "Exact match for citation #{ERB::Util.html_escape(plan.query)}",
                        source: :citation)
      Results.new(
        query: plan.query, query_type: "citation", reason: plan.reason,
        entries: [entry], total: 1, page: 1, per:,
        facets: FacetSet.build(PostgresAdapter.facet_counts(Document.where(id: document.id))),
        engines: ["postgres"]
      )
    end

    # --- Strategy: terms-and-connectors --------------------------------

    def lexical_results(plan, filters, page, per, sort, mode:)
      if OpenSearchAdapter.available?
        os = OpenSearchAdapter.search(query: plan.query, mode: os_mode(mode), filters:, sort:, page:, per:)
        entries = hydrate(os[:hits].map { |h| [h.document_id, h.score, h.snippet, :opensearch] })
        Results.new(query: plan.query, query_type: mode.to_s, reason: plan.reason,
                    entries:, total: os[:total], page:, per:,
                    facets: FacetSet.build(os[:facets]), engines: ["opensearch"])
      else
        pg = PostgresAdapter.new(scope: scope(filters))
        result = pg.search(query: plan.query, mode:, sort:, page:, per:)
        entries = hydrate(result[:hits].map { |h| [h.document_id, h.score, h.snippet, :postgres] })
        facet_scope = pg.matching_scope(query: plan.query, mode:)
        Results.new(query: plan.query, query_type: mode.to_s, reason: plan.reason,
                    entries:, total: result[:total], page:, per:,
                    facets: FacetSet.build(PostgresAdapter.facet_counts(facet_scope)),
                    engines: ["postgres"])
      end
    end

    # --- Strategy: hybrid natural language ------------------------------

    def hybrid_results(plan, filters, page, per, sort)
      engines = []
      filtered = scope(filters)

      if OpenSearchAdapter.available?
        lexical_ids = OpenSearchAdapter.ranked_ids(query: plan.query, mode: :match,
                                                   filters:, limit: HYBRID_POOL)
        engines << "opensearch"
      else
        lexical_ids = PostgresAdapter.new(scope: filtered)
                                     .ranked_ids(query: plan.query, mode: :natural, limit: HYBRID_POOL)
        engines << "postgres"
      end

      scope_ids = Filters.active?(filters) ? filtered.limit(10_000).pluck(:id) : nil
      vector_hits = VectorAdapter.new.search(plan.query, scope_ids:)
      vector_ids = vector_hits.map(&:document_id)
      engines << "pgvector" if vector_ids.any?

      fused_ids = ReciprocalRankFusion.fuse(lexical_ids, vector_ids)
      total = fused_ids.size
      page_ids = fused_ids.slice((page - 1) * per, per) || []

      snippets = lexical_snippets(plan.query, page_ids & lexical_ids)
      vector_snippets = vector_hits.to_h { |h| [h.document_id, h.content] }

      entries = hydrate(page_ids.each_with_index.map { |id, i|
        [id, total - ((page - 1) * per + i), snippets[id] || excerpt(vector_snippets[id]),
         snippets.key?(id) ? :lexical : :semantic]
      })

      entries = resort(entries, sort)

      Results.new(query: plan.query, query_type: "natural", reason: plan.reason,
                  entries:, total:, page:, per:,
                  facets: FacetSet.build(PostgresAdapter.facet_counts(Document.where(id: fused_ids))),
                  engines:)
    end

    def lexical_snippets(query, ids)
      return {} if ids.empty?

      pg = PostgresAdapter.new
      pg.snippets_for(ids, pg.ts_expression(query, :natural))
    end

    def excerpt(content)
      content&.truncate(220)
    end

    def hydrate(rows)
      documents = Document.includes(:court, :jurisdiction, :primary_topic)
                          .where(id: rows.map(&:first)).index_by(&:id)
      rows.filter_map do |id, score, snippet, source|
        document = documents[id]
        next if document.nil?

        Entry.new(document:, score: score.to_f, snippet:, source:)
      end
    end

    def resort(entries, sort)
      case sort
      when "date" then entries.sort_by { |e| [e.document.decided_on || Date.new(1700), e.document.id] }.reverse
      when "cited" then entries.sort_by { |e| -e.document.cited_by_count }
      else entries
      end
    end

    def os_mode(mode)
      mode == :boolean ? :query_string : :match
    end
  end
end
