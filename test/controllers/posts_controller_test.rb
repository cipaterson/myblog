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

  test "the admin can backdate a post when creating it" do
    sign_in_as @admin

    post posts_url, params: {
      post: { title: "From the archive", body: "<div>Body</div>",
              published_at: "2019-03-14T09:30", published: "1" }
    }

    created = Post.find_by!(slug: "from-the-archive")
    assert created.published?
    assert_equal Time.utc(2019, 3, 14, 9, 30), created.published_at
  end

  test "the admin can backdate an already-published post" do
    sign_in_as @admin
    original = @published.published_at

    patch post_url(@published), params: { post: { published_at: "2019-12-25T08:00", published: "1" } }

    @published.reload
    assert_equal Time.utc(2019, 12, 25, 8, 0), @published.published_at
    assert_not_equal original, @published.published_at
  end

  test "a blank publication date publishes the post now" do
    sign_in_as @admin

    patch post_url(@draft), params: { post: { published_at: "", published: "1" } }

    @draft.reload
    assert @draft.published?
    assert_in_delta Time.current, @draft.published_at, 5
  end

  test "a publication date on an unpublished post is discarded" do
    sign_in_as @admin

    patch post_url(@draft), params: { post: { published_at: "2019-03-14T09:30", published: "0" } }

    @draft.reload
    assert_not @draft.published?
    assert_nil @draft.published_at
  end

  test "the edit form pre-fills the current publication date" do
    sign_in_as @admin
    expected = @published.published_at.strftime("%Y-%m-%dT%H:%M")

    get edit_post_url(@published)

    assert_response :success
    assert_select "input[type=datetime-local][value=?]", expected
  end

  test "the publication date field is hidden until the post is published" do
    sign_in_as @admin

    get edit_post_url(@published)
    assert_select "[data-publication-date-target=field]:not([hidden])"

    get edit_post_url(@draft)
    assert_select "[data-publication-date-target=field][hidden]"
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
