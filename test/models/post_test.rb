require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "a title is required" do
    assert_not Post.new(title: "").valid?
  end

  test "slugs are generated from the title" do
    post = Post.create!(title: "Hello, World! Again")
    assert_equal "hello-world-again", post.slug
    assert_equal "hello-world-again", post.to_param
  end

  test "duplicate titles get distinct slugs" do
    Post.create!(title: "Same title")
    second = Post.create!(title: "Same title")

    assert_equal "same-title-2", second.slug
  end

  test "a slug survives a retitle so published URLs keep working" do
    post = Post.create!(title: "Original")
    post.update!(title: "Something else")

    assert_equal "original", post.slug
  end

  test "published scope excludes drafts" do
    assert_includes Post.published, posts(:published)
    assert_not_includes Post.published, posts(:draft)
  end

  test "the published flag toggles published_at" do
    post = Post.new(title: "Toggle")

    post.published = "1"
    assert post.published?

    post.published = "0"
    assert_not post.published?
  end

  test "publishing twice does not move the original publication date" do
    post = Post.create!(title: "Stable date", published: "1")
    original = post.published_at

    post.published = "1"
    assert_equal original, post.published_at
  end

  test "the publication date can be chosen instead of defaulting to now" do
    chosen = Time.utc(2019, 3, 14, 9, 30)

    post = Post.create!(title: "Backdated", published_at: chosen, published: "1")

    assert_equal chosen, post.published_at
    assert_equal chosen, post.date
  end

  test "a published post with a blank date falls back to now" do
    post = Post.create!(title: "Undated", published_at: nil, published: "1")

    assert_in_delta Time.current, post.published_at, 5
  end

  test "unpublishing discards the publication date" do
    post = Post.create!(title: "Retracted", published_at: Time.utc(2019, 3, 14), published: "1")

    post.published = "0"

    assert_nil post.published_at
    assert_not post.published?
  end

  test "a date on an unpublished post is ignored" do
    post = Post.create!(title: "Future", published_at: Time.utc(2019, 3, 14), published: "0")

    assert_nil post.published_at
  end

  test "editing the publication date keeps the post published" do
    post = posts(:published)

    post.update!(published_at: Time.utc(2019, 12, 25, 8), published: "1")

    assert post.reload.published?
    assert_equal Time.utc(2019, 12, 25, 8), post.published_at
  end

  test "a chosen publication date reorders the index" do
    recent = posts(:published)
    recent.update!(published_at: 1.day.ago, published: "1")

    older = Post.create!(title: "Older", published_at: 6.months.ago, published: "1")

    assert_equal [ recent, older ], Post.published.newest_first.to_a
  end

  test "non-image embeds are rejected" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("not an image"), filename: "notes.txt", content_type: "text/plain"
    )
    post = Post.new(title: "Bad embed", body: attachment_html(blob))

    assert_not post.valid?
    assert_match(/PNG, JPEG, GIF or WebP/, post.errors.full_messages.to_sentence)
  end

  private
    def attachment_html(blob)
      %(<div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment></div>)
    end
end
