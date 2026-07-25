# Populate the env vars that config/litestream.yml references, sourced from the
# same digitalocean: credentials namespace that Active Storage uses — no new
# secrets required.
if Rails.env.production?
  creds = Rails.application.credentials.digitalocean
  if creds
    ENV["LITESTREAM_REPLICA_BUCKET"]    ||= creds.bucket.to_s
    ENV["LITESTREAM_REPLICA_REGION"]    ||= creds.region.to_s
    ENV["LITESTREAM_REPLICA_ENDPOINT"]  ||= "https://#{creds.region}.digitaloceanspaces.com"
    ENV["LITESTREAM_ACCESS_KEY_ID"]     ||= creds.access_key_id.to_s
    ENV["LITESTREAM_SECRET_ACCESS_KEY"] ||= creds.secret_access_key.to_s
  end
end
