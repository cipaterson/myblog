class PostsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]

  before_action :set_post, only: %i[ show edit update destroy ]

  def index
    @posts = visible_posts.newest_first
  end

  def show
    # Deliberately not @post.comments.new: an unsaved record added to the
    # association would be counted in the comment tally on the page.
    @comment = Comment.new
  end

  def new
    @post = Post.new
  end

  def edit
  end

  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to @post, notice: "Post created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: "Post updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @post.destroy!
    redirect_to posts_path, notice: "Post deleted.", status: :see_other
  end

  private
    # Drafts are invisible to the public: looking one up as a guest 404s rather
    # than revealing that it exists.
    def set_post
      @post = visible_posts.find_by!(slug: params[:id])
    end

    def visible_posts
      authenticated? ? Post.all : Post.published
    end

    def post_params
      params.expect(post: [ :title, :body, :published ])
    end
end
