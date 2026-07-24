require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @published = posts(:published)
    @draft = posts(:draft)
    @admin = users(:one)
  end

  # --- public access ---

  test "anyone can read the index" do
    get root_url
    assert_response :success
    assert_match @published.title, response.body
  end

  test "index hides drafts from guests" do
    get root_url
    assert_no_match(/#{@draft.title}/, response.body)
  end

  test "index shows drafts to the admin" do
    sign_in_as @admin
    get root_url
    assert_match @draft.title, response.body
  end

  test "anyone can read a published post" do
    get post_url(@published)
    assert_response :success
  end

  test "a draft is not found for guests" do
    get post_url(@draft)
    assert_response :not_found
  end

  test "the admin can preview a draft" do
    sign_in_as @admin
    get post_url(@draft)
    assert_response :success
  end

  test "posts are addressed by slug" do
    get post_url(@published)
    assert_equal "/posts/a-published-post", path
  end

  # --- admin gating ---

  test "guests are redirected away from writing actions" do
    get new_post_url
    assert_redirected_to new_session_url

    get edit_post_url(@published)
    assert_redirected_to new_session_url

    assert_no_difference "Post.count" do
      post posts_url, params: { post: { title: "Sneaky", body: "<div>hi</div>" } }
    end
    assert_redirected_to new_session_url

    patch post_url(@published), params: { post: { title: "Hijacked" } }
    assert_redirected_to new_session_url
    assert_equal "A published post", @published.reload.title

    assert_no_difference "Post.count" do
      delete post_url(@published)
    end
    assert_redirected_to new_session_url
  end

  test "the admin can create a post" do
    sign_in_as @admin

    assert_difference "Post.count", 1 do
      post posts_url, params: { post: { title: "Brand new", body: "<div>Body</div>", published: "1" } }
    end

    created = Post.find_by!(slug: "brand-new")
    assert created.published?
    assert_redirected_to post_url(created)
  end

  test "a post created without publishing stays a draft" do
    sign_in_as @admin
    post posts_url, params: { post: { title: "Work in progress", body: "<div>x</div>", published: "0" } }

    assert_not Post.find_by!(slug: "work-in-progress").published?
  end

  test "the admin can update and delete a post" do
    sign_in_as @admin

    patch post_url(@published), params: { post: { title: "Edited title" } }
    assert_equal "Edited title", @published.reload.title

    assert_difference "Post.count", -1 do
      delete post_url(@published)
    end
    assert_redirected_to posts_url
  end

  test "a post without a title is rejected" do
    sign_in_as @admin

    assert_no_difference "Post.count" do
      post posts_url, params: { post: { title: "", body: "<div>x</div>" } }
    end
    assert_response :unprocessable_content
  end

  test "deleting a post deletes its comments" do
    sign_in_as @admin

    assert_difference "Comment.count", -@published.comments.count do
      delete post_url(@published)
    end
  end
end
