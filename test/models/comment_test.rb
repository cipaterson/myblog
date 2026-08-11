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

  test "a reply must belong to the same post as its parent" do
    reply = Comment.new(post: posts(:published), parent: comments(:draft_comment),
                        author_name: "Jane", body: "Hi")

    assert_not reply.valid?
    assert reply.errors[:parent].any?
  end

  test "a reply cannot be replied to" do
    reply = Comment.new(post: posts(:published), parent: comments(:reply),
                        author_name: "Jane", body: "Hi")

    assert_not reply.valid?
    assert reply.errors[:parent].any?
  end

  test "a top-level comment is valid with a parent on the same post" do
    reply = Comment.new(post: posts(:published), parent: comments(:one),
                        author_name: "Jane", body: "Hi")

    assert reply.valid?
  end

  test "replies are destroyed with their parent" do
    parent = comments(:one)
    reply_id = comments(:reply).id
    assert_difference "Comment.count", -(parent.replies.count + 1) do
      parent.destroy!
    end
    assert_nil Comment.find_by(id: reply_id)
  end
end
