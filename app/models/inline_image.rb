# Single source of truth for how inline post images are rendered.
#
# Both app/views/active_storage/blobs/_blob.html.erb and PreprocessEmbedsJob
# refer to this, so the variant the job warms up is keyed identically to the one
# the view asks for. Changing the width here is enough to change it everywhere;
# originals are kept, so existing posts just re-render at the new size.
module InlineImage
  # Caps width at 800px, keeps the aspect ratio, and never upscales anything
  # already narrower than that.
  VARIANT = { resize_to_limit: [ 800, nil ] }.freeze

  MAX_BYTE_SIZE = 10.megabytes

  CONTENT_TYPES = %w[ image/png image/jpeg image/gif image/webp ].freeze
end
