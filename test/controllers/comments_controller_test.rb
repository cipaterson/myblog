require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @post = posts(:published)
    @draft = posts(:draft)
    @admin = users(:one)
  end

  test "a guest can comment on a published post" do
    assert_difference "Comment.count", 1 do
      post post_comments_url(@post), params: comment_params
    end

    comment = Comment.last
    assert_equal "Jane", comment.author_name
    assert_redirected_to post_path(@post, anchor: "comment-#{comment.id}")
  end

  test "a new comment is visible immediately" do
    post post_comments_url(@post), params: comment_params(body: "Instantly visible")
    follow_redirect!

    assert_match "Instantly visible", response.body
  end

  test "comments cannot be left on a draft" do
    assert_no_difference "Comment.count" do
      post post_comments_url(@draft), params: comment_params
    end
    assert_response :not_found
  end

  test "a blank comment is rejected" do
    assert_no_difference "Comment.count" do
      post post_comments_url(@post), params: comment_params(body: "")
    end
    assert_response :unprocessable_content
  end

  # --- spam guards ---

  test "a filled honeypot is silently dropped" do
    assert_no_difference "Comment.count" do
      post post_comments_url(@post), params: comment_params.merge(nickname: "spambot")
    end

    # Reports success so the bot learns nothing.
    assert_redirected_to post_path(@post)
  end

  test "a submission faster than a human is silently dropped" do
    assert_no_difference "Comment.count" do
      post post_comments_url(@post), params: comment_params(rendered_at: Time.current)
    end
    assert_redirected_to post_path(@post)
  end

  test "a missing or forged timestamp is silently dropped" do
    assert_no_difference "Comment.count" do
      post post_comments_url(@post), params: comment_params.except(:form_rendered_at)
    end

    assert_no_difference "Comment.count" do
      post post_comments_url(@post), params: comment_params.merge(form_rendered_at: "not-a-signed-value")
    end
  end

  # --- moderation ---

  test "only the admin can delete a comment" do
    comment = comments(:one)

    assert_no_difference "Comment.count" do
      delete comment_url(comment)
    end
    assert_redirected_to new_session_url

    sign_in_as @admin
    assert_difference "Comment.count", -1 do
      delete comment_url(comment)
    end
    assert_redirected_to post_path(comment.post)
  end

  private
    def comment_params(body: "A real comment.", rendered_at: 1.minute.ago)
      {
        comment: { author_name: "Jane", body: body },
        form_rendered_at: Rails.application.message_verifier(:comment_form).generate(rendered_at.to_i)
      }
    end
end
