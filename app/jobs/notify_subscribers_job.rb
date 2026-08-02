class NotifySubscribersJob < ApplicationJob
  queue_as :default

  def perform(post)
    Subscriber.confirmed.find_each do |subscriber|
      SubscriberMailer.new_post_notification(subscriber, post).deliver_later
    end
  end
end
