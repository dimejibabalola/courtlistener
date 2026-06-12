module Ai
  module Clients
    # OpenAI chat completions via plain HTTP.
    class OpenAiClient
      ENDPOINT = URI("https://api.openai.com/v1/chat/completions")

      def initialize(api_key: nil)
        @api_key = api_key.presence || ENV["OPENAI_API_KEY"]
      end

      def complete(system:, user:, model:, max_tokens: 2048)
        raise Ai::ProviderError, "No OpenAI API key configured. Add one in Settings." if @api_key.blank?

        response = Net::HTTP.post(
          ENDPOINT,
          {
            model: model,
            max_completion_tokens: max_tokens,
            messages: [
              { role: "system", content: system },
              { role: "user", content: user }
            ]
          }.to_json,
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json"
        )
        body = JSON.parse(response.body)
        unless response.code.to_i == 200
          raise Ai::ProviderError, "OpenAI API error: #{body.dig('error', 'message').to_s.truncate(180)}"
        end

        body.dig("choices", 0, "message", "content").to_s
      rescue JSON::ParserError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
        raise Ai::ProviderError, "OpenAI request failed: #{e.message.to_s.truncate(180)}"
      end
    end
  end
end
