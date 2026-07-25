require "test_helper"

# The headline feature: PreprocessEmbedsJob resizes uploaded images to 800px and
# replaces the original blob in storage, so only the smaller file is kept.
class InlineImageTest < ActiveSupport::TestCase
  test "a wide image is replaced with an 800px version" do
    blob = blob_for("wide.png")
    post = Post.create!(title: "Wide", body: attachment_html(blob), published: "1")
    PreprocessEmbedsJob.perform_now(post)

    width, height = dimensions_of(blob.reload.download)
    assert_equal 800, width
    assert_equal 533, height, "2400x1600 scaled to 800 wide should be 533 tall"
  end

  test "an image narrower than 800px is not upscaled" do
    blob = blob_for("narrow.png")
    post = Post.create!(title: "Narrow", body: attachment_html(blob), published: "1")
    PreprocessEmbedsJob.perform_now(post)

    width, height = dimensions_of(blob.reload.download)
    assert_equal 400, width
    assert_equal 300, height
  end

  test "the original blob is overwritten, not kept" do
    blob = blob_for("wide.png")
    post = Post.create!(title: "Overwritten", body: attachment_html(blob), published: "1")
    PreprocessEmbedsJob.perform_now(post)

    assert_equal [ 800, 533 ], dimensions_of(blob.reload.download)
  end

  test "the job marks the blob as resized and purges variant records" do
    blob = blob_for("wide.png")
    post = Post.create!(title: "Flags", body: attachment_html(blob), published: "1")
    PreprocessEmbedsJob.perform_now(post)

    blob.reload
    assert blob.metadata["resized"], "expected blob.metadata['resized'] to be true"
    assert_equal 0, blob.variant_records.count
  end

  test "posts render inline images via the blob url, not a /representations/ path" do
    blob = blob_for("wide.png")
    post = Post.create!(title: "Rendered", body: attachment_html(blob), published: "1")
    PreprocessEmbedsJob.perform_now(post)

    ActiveStorage::Current.url_options = { host: "example.com" }
    html = ApplicationController.render(partial: "posts/body", locals: { post: post })

    assert_no_match "/representations/", html
    assert_match 'loading="lazy"', html
  end

  test "the job is idempotent — running it twice does not change the blob" do
    blob = blob_for("wide.png")
    post = Post.create!(title: "Idempotent", body: attachment_html(blob), published: "1")
    PreprocessEmbedsJob.perform_now(post)

    checksum_after_first_run = blob.reload.checksum
    PreprocessEmbedsJob.perform_now(post)

    assert_equal checksum_after_first_run, blob.reload.checksum
  end

  private
    def blob_for(name)
      ActiveStorage::Blob.create_and_upload!(
        io: file_fixture(name).open, filename: name, content_type: "image/png"
      )
    end

    def dimensions_of(bytes)
      image = Vips::Image.new_from_buffer(bytes, "")
      [ image.width, image.height ]
    end

    def attachment_html(blob)
      %(<div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment></div>)
    end
end
