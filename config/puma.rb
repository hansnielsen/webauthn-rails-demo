if ENV.fetch("RAILS_ENV") == 'development'
  ssl_bind '127.0.0.1', '3000', {
    key: File.join(__dir__, 'tls', 'localhost-key.pem'),
    cert: File.join(__dir__, 'tls', 'localhost.pem'),
    verify_mode: 'none'
  }
end
