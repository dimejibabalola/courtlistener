module Ocr
  # MinerU document-extraction backend (https://mineru.net) — high-quality
  # PDF -> markdown conversion, including scanned documents.
  #
  #   MINERU_MODE=local  -> POST the file to a self-hosted MinerU service
  #                         (MINERU_LOCAL_URL, /file_parse endpoint)
  #   MINERU_MODE=api    -> hosted API: request an upload slot, PUT the file,
  #                         poll the extract task, unzip the markdown result
  #   MINERU_MODE=disabled (or unset) -> never used
  #
  # Failures raise Ocr::MineruClient::Error; TextExtractor falls back to the
  # local extraction chain.
  class MineruClient
    class Error < StandardError; end

    POLL_INTERVAL = 3
    POLL_LIMIT = 40

    def self.enabled?
      %w[local api].include?(ENV["MINERU_MODE"].to_s)
    end

    def self.mode = ENV["MINERU_MODE"].to_s

    def extract(path, filename:)
      case self.class.mode
      when "local" then extract_local(path, filename:)
      when "api" then extract_hosted(path, filename:)
      else raise Error, "MinerU is disabled"
      end
    end

    private

    def extract_local(path, filename:)
      base = ENV.fetch("MINERU_LOCAL_URL").chomp("/")
      uri = URI("#{base}/file_parse")
      form = [["files", File.open(path), { filename: }], ["return_md", "true"]]
      request = Net::HTTP::Post.new(uri)
      request.set_form(form, "multipart/form-data")
      response = http_for(uri, read_timeout: 300).request(request)
      raise Error, "MinerU local error #{response.code}" unless response.code.to_i == 200

      body = JSON.parse(response.body)
      markdown = dig_markdown(body)
      raise Error, "MinerU local returned no text" if markdown.blank?

      markdown
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError => e
      raise Error, "MinerU local request failed: #{e.message}"
    end

    def extract_hosted(path, filename:)
      api_key = ENV["MINERU_API_KEY"]
      raise Error, "MINERU_API_KEY missing" if api_key.blank?

      base = ENV.fetch("MINERU_BASE_URL", "https://mineru.net").chomp("/")
      upload_url, batch_id = request_upload_slot(base, api_key, filename)
      put_file(upload_url, path)
      zip_url = poll_batch(base, api_key, batch_id, filename)
      markdown_from_zip(zip_url)
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError => e
      raise Error, "MinerU API request failed: #{e.message}"
    end

    def request_upload_slot(base, api_key, filename)
      uri = URI("#{base}/api/v4/file-urls/batch")
      response = post_json(uri, { files: [{ name: filename }], enable_ocr: true },
                           "Authorization" => "Bearer #{api_key}")
      data = JSON.parse(response.body)
      raise Error, "MinerU upload-slot error: #{data['msg'] || response.code}" unless data["code"].to_i.zero?

      [data.dig("data", "file_urls", 0), data.dig("data", "batch_id")]
    end

    def put_file(upload_url, path)
      uri = URI(upload_url)
      request = Net::HTTP::Put.new(uri)
      request.body = File.binread(path)
      response = http_for(uri, read_timeout: 300).request(request)
      raise Error, "MinerU file upload failed: #{response.code}" unless response.code.to_i.between?(200, 299)
    end

    def poll_batch(base, api_key, batch_id, filename)
      uri = URI("#{base}/api/v4/extract-results/batch/#{batch_id}")
      POLL_LIMIT.times do
        response = http_for(uri).request(Net::HTTP::Get.new(uri).tap { |r| r["Authorization"] = "Bearer #{api_key}" })
        data = JSON.parse(response.body)
        record = Array(data.dig("data", "extract_result")).find { |r| r["file_name"] == filename } ||
                 Array(data.dig("data", "extract_result")).first
        case record&.fetch("state", nil)
        when "done" then return record["full_zip_url"]
        when "failed" then raise Error, "MinerU extraction failed: #{record['err_msg']}"
        end
        sleep POLL_INTERVAL
      end
      raise Error, "MinerU extraction timed out"
    end

    def markdown_from_zip(zip_url)
      raise Error, "MinerU returned no result archive" if zip_url.blank?

      response = http_for(URI(zip_url), read_timeout: 120).request(Net::HTTP::Get.new(URI(zip_url)))
      raise Error, "MinerU result download failed: #{response.code}" unless response.code.to_i == 200

      markdown = +""
      Tempfile.create(["mineru", ".zip"], binmode: true) do |tmp|
        tmp.write(response.body)
        tmp.flush
        Zip::File.open(tmp.path) do |zip|
          zip.glob("**/*.md").sort_by(&:name).each { |entry| markdown << entry.get_input_stream.read << "\n\n" }
        end
      end
      raise Error, "MinerU archive contained no markdown" if markdown.blank?

      markdown
    end

    def post_json(uri, payload, headers = {})
      request = Net::HTTP::Post.new(uri)
      headers.each { |k, v| request[k] = v }
      request["Content-Type"] = "application/json"
      request.body = payload.to_json
      http_for(uri).request(request)
    end

    def http_for(uri, read_timeout: 30)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = read_timeout
      http
    end

    def dig_markdown(body)
      return body["md_content"] if body["md_content"].present?

      results = body["results"]
      case results
      when Hash then results.values.filter_map { |r| r["md_content"] }.join("\n\n")
      when Array then results.filter_map { |r| r["md_content"] }.join("\n\n")
      end
    end
  end
end
