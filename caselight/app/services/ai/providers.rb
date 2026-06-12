module Ai
  # Registry of switchable model providers. "local" is a deterministic
  # extractive answerer that needs no API key, so the assistant works in a
  # fully offline demo; hosted providers activate when a key is configured
  # (per-user in Settings, or via ANTHROPIC_API_KEY / OPENAI_API_KEY).
  module Providers
    REGISTRY = {
      "local" => {
        label: "Built-in (offline, extractive)",
        models: ["caselight-extractive-1"],
        default_model: "caselight-extractive-1",
        requires_key: false
      },
      "deepseek" => {
        label: "DeepSeek",
        models: ["deepseek-chat", "deepseek-reasoner"],
        default_model: ENV.fetch("DEEPSEEK_MODEL", "deepseek-chat"),
        requires_key: true
      },
      "anthropic" => {
        label: "Anthropic Claude",
        models: ["claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5"],
        default_model: "claude-opus-4-8",
        requires_key: true
      },
      "openai" => {
        label: "OpenAI",
        models: ["gpt-4o", "gpt-4o-mini"],
        default_model: "gpt-4o-mini",
        requires_key: true
      }
    }.freeze

    def self.available_keys = REGISTRY.keys

    def self.fetch(key) = REGISTRY.fetch(key.to_s, REGISTRY["local"])

    def self.models_for(key) = fetch(key)[:models]

    def self.default_model_for(key) = fetch(key)[:default_model]

    def self.client_for(provider, user: nil)
      case provider.to_s
      when "anthropic" then Clients::AnthropicClient.new(api_key: user&.api_key_for("anthropic"))
      when "openai" then Clients::OpenAiClient.new(api_key: user&.api_key_for("openai"))
      when "deepseek" then Clients::DeepSeekClient.new(api_key: user&.api_key_for("deepseek"))
      else Clients::LocalClient.new
      end
    end

    # Resolve the user's configured provider, falling back to local when the
    # chosen provider has no usable key.
    def self.resolve(user)
      provider = user&.ai_provider.presence || "local"
      if fetch(provider)[:requires_key] && user&.api_key_for(provider).blank?
        provider = "local"
      end
      model = user&.ai_model.presence
      model = default_model_for(provider) unless models_for(provider).include?(model)
      [provider, model]
    end
  end
end
