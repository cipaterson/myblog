require "test_helper"

class PostLocationTest < ActiveSupport::TestCase
  test "reads GPS coordinates from a JPEG" do
    coordinates = PostLocation.from_image(file_fixture("gps.jpg"))

    assert_in_delta 43.46744833, coordinates[:latitude], 1e-7
    assert_in_delta 11.88512667, coordinates[:longitude], 1e-7
  end

  test "returns nil for an image without GPS" do
    assert_nil PostLocation.from_image(file_fixture("wide.png"))
  end

  test "returns nil for a missing or unreadable file" do
    assert_nil PostLocation.from_image(Rails.root.join("tmp/does-not-exist.jpg"))
  end
end
