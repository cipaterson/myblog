class SubscriberMailer < ApplicationMailer
  def confirmation_email(subscriber)
    @subscriber = subscriber
    @confirm_url = confirm_subscriber_url(token: subscriber.confirmation_token)
    mail(to: subscriber.email, subject: "Confirm your subscription")
  end

  def new_post_notification(subscriber, post)
    @subscriber = subscriber
    @post = post
    @post_url = post_url(post)
    @unsubscribe_url = unsubscribe_url(token: subscriber.token)
    mail(to: subscriber.email, subject: post.title)
  end
end
