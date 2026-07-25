# Single source of truth for the resize dimensions applied to inline post images.
# PreprocessEmbedsJob reads VARIANT to resize and overwrite the uploaded blob;
# the view then serves the already-resized blob directly via blob.url.
module InlineImage
  VARIANT = { resize_to_limit: [ 800, nil ] }.freeze

  MAX_BYTE_SIZE = 10.megabytes

  CONTENT_TYPES = %w[ image/png image/jpeg image/gif image/webp ].freeze
end
