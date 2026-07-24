require "test_helper"

# The headline feature: images embedded in a post are served at 800px wide,
# whatever was uploaded.
class InlineImageTest < ActiveSupport::TestCase
  test "a wide image is served at 800px, keeping its aspect ratio" do
    width, height = dimensions_of variant_for("wide.png")

    assert_equal 800, width
    assert_equal 533, height, "2400x1600 scaled to 800 wide should be 533 tall"
  end

  test "an image narrower than 800px is not upscaled" do
    width, height = dimensions_of variant_for("narrow.png")

    assert_equal 400, width
    assert_equal 300, height
  end

  test "the original upload is kept, not overwritten" do
    blob = blob_for("wide.png")
    blob.representation(**InlineImage::VARIANT).processed

    assert_equal [ 2400, 1600 ], dimensions_of(blob.download)
  end

  test "the view and the preprocessing job ask for the same variant" do
    blob = blob_for("wide.png")
    post = Post.create!(title: "With an image", body: attachment_html(blob), published: "1")

    # Warming the variant is what PreprocessEmbedsJob does...
    PreprocessEmbedsJob.perform_now(post)

    # ...and it must be the exact variant the rendered page then requests, so
    # the reader gets a cache hit rather than a fresh transform.
    assert blob.reload.variant(**InlineImage::VARIANT).send(:processed?),
      "expected the variant requested by the view to already be processed"
  end

  test "posts render inline images through the variant, not the original blob" do
    blob = blob_for("wide.png")
    post = Post.create!(title: "Rendered", body: attachment_html(blob), published: "1")

    html = ApplicationController.render(partial: "posts/body", locals: { post: post })

    assert_match "/representations/", html
    assert_match 'loading="lazy"', html
  end

  private
    def blob_for(name)
      ActiveStorage::Blob.create_and_upload!(
        io: file_fixture(name).open, filename: name, content_type: "image/png"
      )
    end

    def variant_for(name)
      blob_for(name).representation(**InlineImage::VARIANT).processed.download
    end

    def dimensions_of(bytes)
      image = Vips::Image.new_from_buffer(bytes, "")
      [ image.width, image.height ]
    end

    def attachment_html(blob)
      %(<div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment></div>)
    end
end
