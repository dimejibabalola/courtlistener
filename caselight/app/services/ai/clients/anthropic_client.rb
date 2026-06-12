module Ai
  module Clients
    # Anthropic Messages API via the official SDK.
    class AnthropicClient
      # Models that support adaptive thinking.
      ADAPTIVE_THINKING_MODELS = %w[claude-opus-4-8 claude-opus-4-7 claude-opus-4-6 claude-sonnet-4-6].freeze

      def initialize(api_key: nil)
        @api_key = api_key.presence || ENV["ANTHROPIC_API_KEY"]
      end

      def complete(system:, user:, model:, max_tokens: 2048)
        params = {
          model: model,
          max_tokens: max_tokens,
          system_: [{ type: "text", text: system }],
          messages: [{ role: "user", content: user }]
        }
        params[:thinking] = { type: "adaptive" } if ADAPTIVE_THINKING_MODELS.include?(model)

        message = client.messages.create(**params)
        if message.stop_reason == :refusal
          return "The model declined to answer this request. Try rephrasing the question."
        end

        message.content.filter_map { |block| block.text if block.type == :text }.join("\n")
      rescue Anthropic::APIStatusError => e
        raise Ai::ProviderError, "Anthropic API error (#{e.type}): #{e.message.to_s.truncate(180)}"
      rescue StandardError => e
        raise Ai::ProviderError, "Anthropic request failed: #{e.message.to_s.truncate(180)}"
      end

      private

      def client
        raise Ai::ProviderError, "No Anthropic API key configured. Add one in Settings." if @api_key.blank?

        @client ||= Anthropic::Client.new(api_key: @api_key)
      end
    end
  end
end
