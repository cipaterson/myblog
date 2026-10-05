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

  # --- location ---

  test "extracts a location from the first photo with GPS" do
    post = Post.create!(title: "Trip", body: attachment_html(gps_blob))

    post.extract_location!

    assert_equal "auto", post.location_source
    assert_in_delta 43.46744833, post.latitude, 1e-7
    assert_in_delta 11.88512667, post.longitude, 1e-7
  end

  test "does not override a manually-entered location" do
    post = Post.create!(title: "Trip", body: attachment_html(gps_blob),
                        latitude: 46.12, longitude: 11.56, location_source: "manual")

    post.extract_location!

    assert_equal "manual", post.location_source
    assert_in_delta 46.12, post.latitude, 1e-7
  end

  test "leaves the location blank when no photo has GPS" do
    post = Post.create!(title: "Trip", body: attachment_html(wide_png_blob))

    post.extract_location!

    assert_nil post.latitude
    assert_nil post.longitude
  end

  test "a location needs both coordinates" do
    assert_not Post.new(title: "Half a location", latitude: 46.12).valid?
  end

  test "located scope only includes posts with both coordinates" do
    Post.create!(title: "Somewhere", latitude: 46.12, longitude: 11.56)

    assert_includes Post.located, posts(:published)
    assert_not_includes Post.located, posts(:draft)
  end

  private
    def attachment_html(blob)
      %(<div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment></div>)
    end

    def gps_blob
      ActiveStorage::Blob.create_and_upload!(
        io: file_fixture("gps.jpg").open, filename: "gps.jpg", content_type: "image/jpeg"
      )
    end

    def wide_png_blob
      ActiveStorage::Blob.create_and_upload!(
        io: file_fixture("wide.png").open, filename: "wide.png", content_type: "image/png"
      )
    end
end
