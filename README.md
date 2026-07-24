# Myblog

A small, single-author blog. The admin writes posts in a rich text editor;
anyone can read them and leave a comment without an account.

Images dragged or pasted into a post upload automatically and are served at
**800px wide**, whatever their original size.

## Requirements

- Ruby 3.4.2 (see `.ruby-version`)
- **libvips** — required for image resizing:
  ```sh
  brew install vips           # macOS
  apt-get install libvips     # Debian/Ubuntu
  ```
  The `Dockerfile` already installs it, so this is a local-development step only.

## Getting started

```sh
bin/setup
bin/rails db:seed
bin/dev
```

`db:seed` creates the admin account. It reads `ADMIN_EMAIL` and
`ADMIN_PASSWORD`, falling back to `admin@example.com` / `password123` in
development. Set real values in production:

```sh
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD=... bin/rails db:seed
```

Log in at `/session/new`. There is deliberately no link to it from the public
pages. To change the password later:

```sh
bin/rails console
User.find_by(email_address: "you@example.com").update!(password: "new password")
```

Set `BLOG_NAME` to change the title shown in the header and browser tab.

## How the image resizing works

`InlineImage::VARIANT` (`app/models/inline_image.rb`) is the single definition of
how inline images are rendered:

```ruby
VARIANT = { resize_to_limit: [ 800, nil ] }.freeze
```

`resize_to_limit` caps the width at 800px, preserves the aspect ratio, and never
upscales an image that is already narrower.

Two places use it, and they must agree so the reader gets a cached variant
rather than a fresh transform:

- `app/views/active_storage/blobs/_blob.html.erb` — overrides the Action Text
  default (which is 1024x768) so every embedded image renders through the variant.
- `app/jobs/preprocess_embeds_job.rb` — enqueued after a post is saved to
  generate the variant up front. This is only an optimisation; Active Storage
  will generate it lazily on first request if the queue isn't running.

**Originals are kept.** Changing the width here changes every image on the site
the next time it renders — no re-uploading. Uploads are restricted to PNG, JPEG,
GIF and WebP under 10 MB (`Post#embeds_must_be_reasonable_images`).

## Where uploads are stored

| Environment | Service | Location |
|---|---|---|
| development | `:local` | `storage/` on disk |
| test | `:test` | `tmp/storage/` |
| production | `:digitalocean` | DigitalOcean Spaces |

No credentials are needed to develop or run the tests — only production talks to
Spaces.

### Production setup

Spaces is S3-compatible, so `config/storage.yml` uses Active Storage's stock `S3`
service with a regional endpoint. It reads everything from encrypted credentials:

```sh
bin/rails credentials:edit
```

```yaml
digitalocean:
  access_key_id: ...
  secret_access_key: ...
  region: nyc3          # also used to build the endpoint hostname
  bucket: ...
```

`RAILS_MASTER_KEY` is already passed to production in `config/deploy.yml`, so
nothing further is needed on the server.

**CORS must be configured on the Space.** Action Text uses *direct uploads* — the
browser `PUT`s the file straight to Spaces, bypassing Rails — so without CORS,
dragging an image into the editor fails in production even though everything else
works. In the Space's Settings → CORS allow:

- Origin `https://blog.firstsoftware.cc`, methods `GET` and `PUT`
- Headers `Content-Type`, `Content-MD5`, `Content-Disposition`

The service is configured `public: true`, so objects are uploaded world-readable
and served from permanent, cacheable, unsigned URLs
(`https://<bucket>.<region>.digitaloceanspaces.com/<key>`) rather than expiring
signed ones. Don't add `upload: cache_control:` to the service config — it is
splatted into the presigned PUT without a matching request header, which breaks
direct uploads with a signature mismatch. Set cache TTL at the CDN instead.

To smoke-test credentials without deploying:

```sh
bin/rails runner - <<'RUBY'
require "net/http"
ActiveStorage::Blob # populates service_configurations via an on_load hook
svc = ActiveStorage::Service.configure(
  :digitalocean, Rails.application.config.active_storage.service_configurations
)
key = "smoke-test-#{SecureRandom.hex(4)}"
svc.upload(key, StringIO.new("hello"))
puts "GET: #{Net::HTTP.get_response(URI(svc.url(key))).code} (expect 200)"
svc.delete(key)
RUBY
```

Note the SQLite databases still live on the server's disk via the Kamal volume
`/var/data/myblog/storage` — only uploaded files moved to Spaces.

## Posts

Posts have a `slug` for permanent URLs (`/posts/my-first-post`), generated from
the title on creation and **not** changed by later retitling, so published links
keep working.

A post with no `published_at` is a draft: invisible on the index and a 404 for
guests, but previewable while logged in. The "Published" checkbox on the post
form toggles it.

## Comments

Comments are public and appear immediately. Two guards run before saving, both
of which report success so a bot learns nothing:

- a hidden honeypot field that must stay empty
- a signed render timestamp — anything submitted within 3 seconds is dropped

The admin sees a Delete button on every comment.

## Tests

```sh
bin/rails test
bin/rubocop
bin/brakeman
```

`test/models/inline_image_test.rb` covers the resizing behaviour end to end,
including that a wide image really is downscaled to 800px and a narrow one is
left alone. Fixtures `test/fixtures/files/wide.png` (2400x1600) and `narrow.png`
(400x300) back those tests.
