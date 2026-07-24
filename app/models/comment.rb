class Comment < ApplicationRecord
  belongs_to :post

  normalizes :author_name, with: ->(name) { name.strip }

  validates :author_name, presence: true, length: { maximum: 60 }
  validates :body, presence: true, length: { maximum: 5_000 }

  scope :chronological, -> { order(created_at: :asc) }
end
