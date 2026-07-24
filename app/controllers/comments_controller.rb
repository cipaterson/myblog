class CommentsController < ApplicationController
  allow_unauthenticated_access only: :create

  # Bots fill in every field they find and submit instantly. Anything faster
  # than this is not a human who just read a blog post.
  MINIMUM_FILL_TIME = 3.seconds

  def create
    @post = Post.published.find_by!(slug: params[:post_id])

    if looks_automated?
      # Report success so bots get no signal about what caught them.
      redirect_to post_path(@post), notice: "Comment posted."
      return
    end

    @comment = Comment.new(comment_params.merge(post: @post))

    if @comment.save
      redirect_to post_path(@post, anchor: "comment-#{@comment.id}"), notice: "Comment posted."
    else
      @comment_error = true
      render "posts/show", status: :unprocessable_content
    end
  end

  def destroy
    comment = Comment.find(params[:id])
    post = comment.post
    comment.destroy!

    redirect_to post_path(post), notice: "Comment deleted.", status: :see_other
  end

  private
    def looks_automated?
      params[:nickname].present? || submitted_too_fast?
    end

    def submitted_too_fast?
      rendered_at = Rails.application.message_verifier(:comment_form).verify(params[:form_rendered_at])
      Time.current - Time.at(rendered_at.to_i) < MINIMUM_FILL_TIME
    rescue ActiveSupport::MessageVerifier::InvalidSignature, TypeError
      true
    end

    def comment_params
      params.expect(comment: [ :author_name, :body ])
    end
end
