module Search
  # Layer 1: OpenSearch/Elasticsearch. Primary full-text engine when a
  # cluster is reachable; the app transparently falls back to the Postgres
  # adapter when it is not.
  class OpenSearchAdapter
    INDEX = ENV.fetch("OPENSEARCH_INDEX", "caselight_documents")
    AVAILABILITY_TTL = 30 # seconds

    Hit = Struct.new(:document_id, :score, :snippet, keyword_init: true)

    class << self
      def client
        @client ||= OpenSearch::Client.new(
          url: ENV.fetch("OPENSEARCH_URL", "http://localhost:9200"),
          transport_options: { request: { timeout: 3, open_timeout: 1 } }
        )
      end

      def available?
        return false if ENV["DISABLE_OPENSEARCH"].present?

        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        if @checked_at.nil? || now - @checked_at > AVAILABILITY_TTL
          @available = begin
            client.ping
          rescue StandardError
            false
          end
          @checked_at = now
        end
        @available
      end

      def reset!
        @client = nil
        @checked_at = nil
      end

      def ensure_index!
        return if client.indices.exists?(index: INDEX)

        client.indices.create(index: INDEX, body: {
          settings: {
            analysis: {
              analyzer: {
                legal_english: {
                  type: "custom", tokenizer: "standard",
                  filter: %w[lowercase english_possessive_stemmer english_stemmer]
                }
              },
              filter: {
                english_stemmer: { type: "stemmer", language: "english" },
                english_possessive_stemmer: { type: "stemmer", language: "possessive_english" }
              }
            }
          },
          mappings: {
            properties: {
              title: { type: "text", analyzer: "legal_english", fields: { raw: { type: "keyword" } } },
              summary: { type: "text", analyzer: "legal_english" },
              full_text: { type: "text", analyzer: "legal_english" },
              citations: { type: "keyword" },
              docket_number: { type: "keyword" },
              doc_type: { type: "keyword" },
              practice_area: { type: "keyword" },
              jurisdiction_id: { type: "keyword" },
              court_id: { type: "keyword" },
              court_level: { type: "keyword" },
              topic_id: { type: "keyword" },
              judge_id: { type: "keyword" },
              treatment_status: { type: "keyword" },
              decided_on: { type: "date" },
              cited_by_count: { type: "integer" }
            }
          }
        })
      end

      def index_document(document)
        client.index(index: INDEX, id: document.id, body: as_indexed_json(document))
      end

      def delete_document(document_id)
        client.delete(index: INDEX, id: document_id, ignore: 404)
      end

      def refresh!
        client.indices.refresh(index: INDEX)
      end

      def as_indexed_json(document)
        {
          title: document.title,
          summary: document.summary,
          full_text: document.full_text,
          citations: document.citations.map(&:normalized),
          docket_number: document.docket_number,
          doc_type: document.type,
          practice_area: document.practice_area,
          jurisdiction_id: document.jurisdiction_id&.to_s,
          court_id: document.court_id&.to_s,
          court_level: document.court&.level,
          topic_id: document.primary_topic_id&.to_s,
          judge_id: document.author_judge_id&.to_s,
          treatment_status: document.treatment_status,
          decided_on: document.decided_on,
          cited_by_count: document.cited_by_count
        }
      end

      # mode :query_string (terms-and-connectors) or :match (natural).
      def search(query:, mode: :match, filters: {}, sort: "relevance", page: 1, per: 20)
        body = {
          query: { bool: { must: [query_clause(query, mode)], filter: filter_clauses(filters) } },
          highlight: {
            pre_tags: ["<mark>"], post_tags: ["</mark>"],
            fields: { full_text: { fragment_size: 160, number_of_fragments: 2 },
                      summary: { fragment_size: 160, number_of_fragments: 1 } }
          },
          aggs: aggregations,
          from: (page - 1) * per,
          size: per
        }
        body[:sort] = sort_clause(sort) if sort != "relevance"

        response = client.search(index: INDEX, body:)
        parse_response(response)
      end

      def ranked_ids(query:, mode: :match, filters: {}, limit: 150)
        response = client.search(index: INDEX, body: {
          query: { bool: { must: [query_clause(query, mode)], filter: filter_clauses(filters) } },
          _source: false, size: limit
        })
        response.dig("hits", "hits").map { |h| h["_id"].to_i }
      end

      private

      def query_clause(query, mode)
        if mode == :query_string
          {
            query_string: {
              query: BooleanTranslator.to_query_string(query),
              fields: ["title^3", "summary^2", "full_text", "citations"],
              default_operator: "AND"
            }
          }
        else
          {
            multi_match: {
              query: query,
              fields: ["title^3", "summary^2", "full_text"],
              type: "best_fields",
              fuzziness: "AUTO"
            }
          }
        end
      end

      def filter_clauses(filters)
        f = Filters.normalize(filters)
        clauses = []
        clauses << { term: { jurisdiction_id: f["jurisdiction_id"] } } if f["jurisdiction_id"]
        clauses << { term: { court_level: f["court_level"] } } if f["court_level"]
        clauses << { term: { doc_type: f["doc_type"] } } if f["doc_type"]
        clauses << { term: { practice_area: f["practice_area"] } } if f["practice_area"]
        clauses << { term: { topic_id: f["topic_id"] } } if f["topic_id"]
        clauses << { term: { judge_id: f["judge_id"] } } if f["judge_id"]
        clauses << { term: { treatment_status: f["treatment"] } } if f["treatment"]
        if f["date_from"] || f["date_to"]
          range = {}
          range[:gte] = f["date_from"] if f["date_from"]
          range[:lte] = f["date_to"] if f["date_to"]
          clauses << { range: { decided_on: range } }
        end
        clauses
      end

      def aggregations
        {
          jurisdictions: { terms: { field: "jurisdiction_id", size: 25 } },
          court_levels: { terms: { field: "court_level", size: 5 } },
          doc_types: { terms: { field: "doc_type", size: 5 } },
          practice_areas: { terms: { field: "practice_area", size: 15 } },
          topics: { terms: { field: "topic_id", size: 12 } },
          judges: { terms: { field: "judge_id", size: 12 } },
          treatments: { terms: { field: "treatment_status", size: 4 } }
        }
      end

      def sort_clause(sort)
        case sort
        when "date" then [{ decided_on: { order: "desc", missing: "_last" } }]
        when "cited" then [{ cited_by_count: { order: "desc" } }]
        else ["_score"]
        end
      end

      def parse_response(response)
        hits = response.dig("hits", "hits").map do |h|
          snippet = h.dig("highlight", "full_text")&.join(" … ") ||
                    h.dig("highlight", "summary")&.join(" … ")
          Hit.new(document_id: h["_id"].to_i, score: h["_score"].to_f, snippet:)
        end
        facets = response.fetch("aggregations", {}).transform_values do |agg|
          agg["buckets"].to_h { |b| [b["key"], b["doc_count"]] }
        end
        {
          hits:,
          total: response.dig("hits", "total", "value").to_i,
          facets: facets.symbolize_keys
        }
      end
    end
  end
end
