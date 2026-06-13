module Ai
  module Clients
    # DeepSeek chat completions (OpenAI-compatible API).
    # Models: deepseek-v4-flash, deepseek-v4-pro. Configure via DEEPSEEK_API_KEY,
    # DEEPSEEK_BASE_URL (default https://api.deepseek.com), DEEPSEEK_MODEL.
    class DeepSeekClient
      def initialize(api_key: nil, base_url: nil)
        @api_key = api_key.presence || ENV["DEEPSEEK_API_KEY"]
        @base_url = (base_url.presence || ENV.fetch("DEEPSEEK_BASE_URL", "https://api.deepseek.com")).chomp("/")
      end

      def complete(system:, user:, model:, max_tokens: 2048)
        raise Ai::ProviderError, "No DeepSeek API key configured. Add one in Settings." if @api_key.blank?

        uri = URI("#{@base_url}/chat/completions")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request.body = {
          model: model,
          max_tokens: max_tokens,
          stream: false,
          messages: [
            { role: "system", content: system },
            { role: "user", content: user }
          ]
        }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
                                                           open_timeout: 10, read_timeout: 120) do |http|
          http.request(request)
        end
        body = JSON.parse(response.body)
        unless response.code.to_i == 200
          raise Ai::ProviderError, "DeepSeek API error: #{body.dig('error', 'message').to_s.truncate(180)}"
        end

        message = body.dig("choices", 0, "message") || {}
        # Reasoning models (e.g. deepseek-v4-pro) return reasoning_content
        # separately; only the final content is the grounded answer.
        message["content"].to_s
      rescue JSON::ParserError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
        raise Ai::ProviderError, "DeepSeek request failed: #{e.message.to_s.truncate(180)}"
      end
    end
  end
end
