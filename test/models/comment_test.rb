require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "an author name and body are required" do
    comment = Comment.new(post: posts(:published))

    assert_not comment.valid?
    assert comment.errors[:author_name].any?
    assert comment.errors[:body].any?
  end

  test "surrounding whitespace is trimmed from the author name" do
    comment = Comment.create!(post: posts(:published), author_name: "  Jane  ", body: "Hi")

    assert_equal "Jane", comment.author_name
  end

  test "a comment must belong to a post" do
    assert_not Comment.new(author_name: "Jane", body: "Hi").valid?
  end
end
