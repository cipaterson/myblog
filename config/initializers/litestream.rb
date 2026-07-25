# Wire Litestream credentials from the existing digitalocean: namespace so no
# new secrets are needed. The gem's engine copies these into the LITESTREAM_*
# env vars immediately before calling the binary (commands.rb:149-153).
Rails.application.configure do
  next unless Rails.env.production?

  creds = Rails.application.credentials.digitalocean
  next unless creds

  config.litestream.replica_bucket    = creds.bucket.to_s
  config.litestream.replica_region    = creds.region.to_s
  config.litestream.replica_endpoint  = "https://#{creds.region}.digitaloceanspaces.com"
  config.litestream.replica_key_id    = creds.access_key_id.to_s
  config.litestream.replica_access_key = creds.secret_access_key.to_s
end
