class Post < ApplicationRecord
  has_rich_text :body
  has_many :comments, dependent: :destroy

  validates :title, presence: true, length: { maximum: 200 }
  validate :embeds_must_be_reasonable_images
  validate :location_must_be_sensible

  before_validation :assign_slug, if: -> { slug.blank? && title.present? }

  scope :published, -> { where.not(published_at: nil) }
  scope :located, -> { where.not(latitude: nil).where.not(longitude: nil) }
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

  # Fills latitude/longitude from the first embedded image that has GPS EXIF.
  # Never clobbers a manually-entered location. Called by PreprocessEmbedsJob,
  # which has the original image open (before it is overwritten by the resize).
  def extract_location!
    return if location_source == "manual"
    return if body.blank?

    body.embeds.filter_map(&:blob).select(&:representable?).each do |blob|
      coordinates = blob.open { |file| PostLocation.from_image(file.path) }
      next unless coordinates

      update_columns(
        latitude: coordinates[:latitude],
        longitude: coordinates[:longitude],
        location_source: "auto"
      )
      return
    end
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

    def location_must_be_sensible
      if latitude.present? != longitude.present?
        errors.add(:base, "latitude and longitude must be set together")
      elsif latitude.present? && !latitude.between?(-90, 90)
        errors.add(:latitude, "must be between -90 and 90")
      elsif longitude.present? && !longitude.between?(-180, 180)
        errors.add(:longitude, "must be between -180 and 180")
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
