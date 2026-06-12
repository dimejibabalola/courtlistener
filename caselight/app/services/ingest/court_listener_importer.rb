module Ingest
  # Pulls opinion clusters from the CourtListener REST API (v4) — the Free
  # Law Project's open corpus — and normalizes them into Documents.
  # https://www.courtlistener.com/help/api/rest/
  class CourtListenerImporter < BaseImporter
    BASE_URL = ENV["COURTLISTENER_BASE_URL"].presence&.chomp("/")&.then { |u| u.end_with?("/api/rest/v4") ? u : "#{u}/api/rest/v4" } ||
               "https://www.courtlistener.com/api/rest/v4"

    def initialize(search: nil, court: nil, limit: 50,
                   api_token: ENV["COURTLISTENER_API_KEY"].presence || ENV["COURTLISTENER_API_TOKEN"])
      @search = search
      @court = court
      @limit = limit
      @api_token = api_token
    end

    private

    def each_record
      fetched = 0
      url = clusters_url
      while url && fetched < @limit
        payload = get_json(url)
        payload.fetch("results", []).each do |cluster|
          yield normalize(cluster)
          fetched += 1
          break if fetched >= @limit
        end
        url = payload["next"]
      end
    end

    def clusters_url
      params = { order_by: "-date_filed" }
      params[:q] = @search if @search.present?
      params[:docket__court] = @court if @court.present?
      "#{BASE_URL}/clusters/?#{params.to_query}"
    end

    def normalize(cluster)
      {
        type: "Case",
        title: cluster["case_name"].presence || cluster["case_name_full"].presence || "Untitled",
        citations: Array(cluster["citations"]).map { |c| [c["volume"], c["reporter"], c["page"]].join(" ").strip },
        decided_on: cluster["date_filed"],
        docket_number: cluster["docket_id"]&.to_s,
        full_text: fetch_opinion_text(cluster),
        summary: cluster["syllabus"].presence,
        source_url: "https://www.courtlistener.com#{cluster['absolute_url']}",
        source_name: "CourtListener"
      }
    end

    def fetch_opinion_text(cluster)
      opinion_url = Array(cluster["sub_opinions"]).first
      return nil if opinion_url.blank?

      opinion = get_json(opinion_url)
      opinion["plain_text"].presence || strip_html(opinion["html"].presence || opinion["html_lawbox"])
    rescue StandardError
      nil
    end

    def strip_html(html)
      return nil if html.blank?

      Nokogiri::HTML(html).text.squish
    end

    def get_json(url)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Token #{@api_token}" if @api_token.present?
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
      raise "CourtListener API error #{response.code}" unless response.code.to_i == 200

      JSON.parse(response.body)
    end
  end
end
