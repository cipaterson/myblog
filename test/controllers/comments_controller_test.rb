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

  # --- replies ---

  test "a guest can reply to a comment" do
    parent = comments(:one)

    assert_difference "Comment.count", 1 do
      post post_comments_url(@post), params: comment_params(parent_id: parent.id, body: "A reply.")
    end

    reply = Comment.last
    assert_equal parent, reply.parent
    assert_equal @post, reply.post
    assert_not reply.author?
  end

  test "a reply to a comment on another post is rejected" do
    assert_no_difference "Comment.count" do
      post post_comments_url(@post), params: comment_params(parent_id: comments(:draft_comment).id)
    end
    assert_response :unprocessable_content
  end

  test "a reply rendered after a validation error shows the form under its parent" do
    post post_comments_url(@post), params: comment_params(parent_id: comments(:one).id, body: "")
    assert_response :unprocessable_content

    assert_match "Reply to Existing Commenter", response.body
    assert_select "form[action='/posts/#{@post.slug}/comments'] input[name='comment[parent_id]'][value='#{comments(:one).id}']"
  end

  test "a spammy reply is silently dropped" do
    assert_no_difference "Comment.count" do
      post post_comments_url(@post), params: comment_params(parent_id: comments(:one).id).merge(nickname: "spambot")
    end
    assert_redirected_to post_path(@post)
  end

  test "the admin's reply is marked as author" do
    sign_in_as @admin

    assert_difference "Comment.count", 1 do
      post post_comments_url(@post), params: comment_params(parent_id: comments(:one).id)
    end
    assert Comment.last.author?
  end

  test "comments cannot be left on a draft" do
    assert_no_difference "Comment.count" do
      post post_comments_url(@draft), params: comment_params
    end
    assert_redirected_to root_path
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
    comment = comments(:two)

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
    def comment_params(body: "A real comment.", parent_id: nil, rendered_at: 1.minute.ago)
      {
        comment: { author_name: "Jane", body: body, parent_id: parent_id }.compact,
        form_rendered_at: Rails.application.message_verifier(:comment_form).generate(rendered_at.to_i)
      }
    end
end
