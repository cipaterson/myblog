# Replaces the uploaded original with an 800px-wide resized version so only the
# smaller file is kept in storage. blob.upload overwrites the file in S3 at the
# blob's own key and updates checksum/byte_size/content_type in memory; blob.save!
# persists those changes to the database.
class PreprocessEmbedsJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(post)
    post.body&.embeds&.each do |embed|
      blob = embed.blob
      next unless blob.representable?
      next if blob.metadata["resized"]

      blob.open do |original|
        resized = ImageProcessing::Vips
          .source(original)
          .resize_to_limit(*InlineImage::VARIANT[:resize_to_limit])
          .call

        blob.upload(resized)
        blob.metadata = blob.metadata.merge("resized" => true)
        blob.save!
      ensure
        resized&.close!
      end

      blob.variant_records.each(&:destroy)
    end
  end
end
