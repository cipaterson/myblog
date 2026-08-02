class Post < ApplicationRecord
  has_rich_text :body
  has_many :comments, dependent: :destroy

  validates :title, presence: true, length: { maximum: 200 }
  validate :embeds_must_be_reasonable_images

  before_validation :assign_slug, if: -> { slug.blank? && title.present? }

  scope :published, -> { where.not(published_at: nil) }
  scope :newest_first, -> { order(Arel.sql("COALESCE(published_at, created_at) DESC")) }

  after_commit :preprocess_embeds, on: %i[ create update ]
  after_commit :notify_subscribers_of_publish, on: :update

  # Friendly URLs: /posts/my-first-post rather than /posts/1.
  def to_param
    slug
  end

  def published?
    published_at.present?
  end

  # Backs the "Publish" checkbox on the post form.
  def published=(value)
    if ActiveModel::Type::Boolean.new.cast(value)
      self.published_at ||= Time.current
    else
      self.published_at = nil
    end
  end

  alias_method :published, :published?

  def date
    published_at || created_at
  end

  private
    def assign_slug
      base = title.parameterize.presence || "post"
      candidate = base
      suffix = 2

      while Post.where.not(id: id).exists?(slug: candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end

      self.slug = candidate
    end

    def embeds_must_be_reasonable_images
      return if body.blank?

      body.body.attachables.grep(ActiveStorage::Blob).each do |blob|
        unless blob.content_type.in?(InlineImage::CONTENT_TYPES)
          errors.add(:body, "can only embed PNG, JPEG, GIF or WebP images")
        end

        if blob.byte_size > InlineImage::MAX_BYTE_SIZE
          errors.add(:body, "images must be smaller than #{InlineImage::MAX_BYTE_SIZE / 1.megabyte} MB")
        end
      end
    end

    def preprocess_embeds
      PreprocessEmbedsJob.perform_later(self)
    end

    def notify_subscribers_of_publish
      if saved_change_to_published_at? && published_at.present? && published_at_before_last_save.nil?
        NotifySubscribersJob.perform_later(self)
      end
    end
end
