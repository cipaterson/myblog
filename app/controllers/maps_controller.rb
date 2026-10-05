class MapsController < ApplicationController
  allow_unauthenticated_access

  def index
    @posts = Post.published.located.newest_first
  end
end
