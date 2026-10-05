require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @published = posts(:published)
  end

  test "the map page is public" do
    get map_url
    assert_response :success
  end

  test "the map embeds markers for located, published posts" do
    get map_url

    markers = JSON.parse(
      Nokogiri::HTML(response.body).at_css("#map")["data-map-markers"]
    )

    assert_equal 1, markers.length
    assert_equal @published.title, markers.first["title"]
    assert_equal post_path(@published), markers.first["url"]
    assert_equal @published.latitude.to_f, markers.first["lat"]
  end

  test "drafts and unlocated posts never appear on the map" do
    get map_url

    markers = JSON.parse(
      Nokogiri::HTML(response.body).at_css("#map")["data-map-markers"]
    )

    assert_empty markers.map { |marker| marker["title"] } & [ posts(:draft).title ]
  end
end
