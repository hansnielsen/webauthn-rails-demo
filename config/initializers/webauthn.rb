WebAuthn.configure do |config|
  config.origin = "https://localhost:3000"
  config.rp_id = Rails.configuration.app_id
end
