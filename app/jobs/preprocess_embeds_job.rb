# Warms up the 800px variant for every image embedded in a post, so the first
# reader doesn't pay for the transform.
#
# This is purely an optimisation: Active Storage generates the variant lazily on
# first request anyway, so the post still renders correctly if the queue isn't
# running.
class PreprocessEmbedsJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(post)
    post.body&.embeds&.each do |embed|
      blob = embed.blob
      next unless blob.representable?

      blob.representation(**InlineImage::VARIANT).processed
    end
  end
end
