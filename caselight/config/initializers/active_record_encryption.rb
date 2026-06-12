# Derive Active Record encryption keys from secret_key_base when explicit
# keys are not configured in credentials. This keeps per-user API keys
# encrypted at rest without requiring extra setup in development/demo
# environments. For production, set real keys with `bin/rails db:encryption:init`.
Rails.application.configure do
  next if config.active_record.encryption.primary_key.present?

  base = Rails.application.secret_key_base
  config.active_record.encryption.primary_key = Digest::SHA256.hexdigest("#{base}:are-primary")[0, 32]
  config.active_record.encryption.deterministic_key = Digest::SHA256.hexdigest("#{base}:are-deterministic")[0, 32]
  config.active_record.encryption.key_derivation_salt = Digest::SHA256.hexdigest("#{base}:are-salt")[0, 32]
end
