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

  test "a post with an embedded photo renders without ActiveStorage url errors" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("gps.jpg").open, filename: "gps.jpg", content_type: "image/jpeg"
    )
    post = Post.create!(title: "With photo", published_at: Time.current,
                        body: %(<div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment></div>))

    get post_url(post)
    assert_response :success
    assert_match %r{/rails/active_storage/}, response.body
  end

  test "replies are shown nested under their parent with an author badge" do
    get post_url(@published)
    assert_response :success

    assert_select "#comment-#{comments(:one).id} .comment__replies #comment-#{comments(:reply).id}"
    assert_select ".comment--reply .badge--author", text: "Author"
  end

  test "a draft redirects guests to root" do
    get post_url(@draft)
    assert_redirected_to root_path
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

  test "a post created with coordinates marks its location as manual" do
    sign_in_as @admin

    post posts_url, params: {
      post: { title: "Somewhere", body: "<div>Body</div>", latitude: "46.12", longitude: "11.56" }
    }

    created = Post.find_by!(slug: "somewhere")
    assert_equal "manual", created.location_source
    assert_in_delta 46.12, created.latitude, 1e-7
  end

  test "blank coordinates clear a location and allow auto-detection again" do
    sign_in_as @admin

    patch post_url(@published), params: { post: { title: "Retitled", latitude: "", longitude: "" } }

    @published.reload
    assert_nil @published.latitude
    assert_nil @published.longitude
    assert_nil @published.location_source
  end

  test "deleting a post deletes its comments" do
    sign_in_as @admin

    assert_difference "Comment.count", -@published.comments.count do
      delete post_url(@published)
    end
  end
end
