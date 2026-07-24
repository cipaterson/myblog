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
