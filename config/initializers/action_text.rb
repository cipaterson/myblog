# Action Text sanitizes rendered content against an allowlist that doesn't
# include `loading`, so the lazy-loading hint on inline images in
# app/views/active_storage/blobs/_blob.html.erb would be stripped before it
# reached the page. Re-add it to the default list.
Rails.application.config.to_prepare do
  ActionText::ContentHelper.allowed_attributes =
    ActionText::ContentHelper.sanitizer.class.allowed_attributes +
    ActionText::Attachment::ATTRIBUTES +
    [ "loading" ]
end
