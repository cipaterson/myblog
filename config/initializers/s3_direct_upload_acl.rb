# DigitalOcean Spaces ignores the ACL baked into pre-signed PUT URLs; it only
# applies the ACL when x-amz-acl is sent as an explicit request header. This
# patch adds that header to what Rails returns to the browser for direct uploads,
# matching what the service already sends for server-side uploads via upload_options.
ActiveSupport.on_load(:active_storage) do
  ActiveStorage::Service::S3Service.prepend(Module.new do
    def headers_for_direct_upload(...)
      super.merge("x-amz-acl" => upload_options[:acl]).compact
    end
  end)
end
