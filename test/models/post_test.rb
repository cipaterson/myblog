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
