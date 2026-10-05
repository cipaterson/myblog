class ApplicationController < ActionController::Base
  # Rails 8.1 dropped the middleware that set this; blob.url (used for inline
  # images in _blob.html.erb) needs per-request url_options to build disk URLs.
  include ActiveStorage::SetCurrent
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :redirect_to_root

  private
    def redirect_to_root
      redirect_to root_path, status: :moved_permanently
    end
end
