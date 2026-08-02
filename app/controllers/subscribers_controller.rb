class SubscribersController < ApplicationController
  allow_unauthenticated_access

  def create
    email = params[:email].to_s.strip.downcase
    @subscriber = Subscriber.find_or_initialize_by(email: email)

    if @subscriber.confirmed?
      redirect_to root_path, notice: "#{email} is already subscribed."
      return
    end

    if @subscriber.new_record?
      unless @subscriber.save
        redirect_to root_path, alert: @subscriber.errors.full_messages.to_sentence
        return
      end
    else
      @subscriber.update!(confirmation_token: unique_token) unless @subscriber.confirmation_token?
    end

    SubscriberMailer.confirmation_email(@subscriber).deliver_later
    redirect_to root_path, notice: "Check your inbox — we've sent a confirmation link to #{email}."
  end

  def confirm
    @subscriber = Subscriber.find_by(confirmation_token: params[:token])

    if @subscriber.nil?
      redirect_to root_path, alert: "That confirmation link is invalid or has already been used."
      return
    end

    @subscriber.confirm!
  end

  def destroy
    subscriber = Subscriber.find_by(token: params[:token])
    subscriber&.destroy
    render :unsubscribed
  end

  private

    def unique_token
      loop do
        candidate = SecureRandom.urlsafe_base64(32)
        break candidate unless Subscriber.exists?(confirmation_token: candidate)
      end
    end
end
