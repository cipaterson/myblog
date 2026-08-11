class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  normalizes :author_name, with: ->(name) { name.strip }

  validates :author_name, presence: true, length: { maximum: 60 }
  validates :body, presence: true, length: { maximum: 5_000 }
  validate :parent_belongs_to_same_post
  validate :parent_is_top_level

  scope :chronological, -> { order(created_at: :asc) }
  scope :top_level, -> { where(parent_id: nil) }

  private
    def parent_belongs_to_same_post
      return if parent.nil? || parent.post_id == post_id

      errors.add(:parent, "must belong to the same post")
    end

    def parent_is_top_level
      return if parent.nil? || parent.parent_id.nil?

      errors.add(:parent, "cannot be a reply itself")
    end
end
