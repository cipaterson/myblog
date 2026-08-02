class Subscriber < ApplicationRecord
  VALID_EMAIL = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  validates :email, presence: true, format: { with: VALID_EMAIL }, uniqueness: { case_sensitive: false }

  scope :confirmed, -> { where.not(confirmed_at: nil) }

  before_create :generate_tokens

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current, confirmation_token: nil)
  end

  private

    def generate_tokens
      self.token = unique_token(:token)
      self.confirmation_token = unique_token(:confirmation_token)
    end

    def unique_token(column)
      loop do
        candidate = SecureRandom.urlsafe_base64(32)
        break candidate unless Subscriber.exists?(column => candidate)
      end
    end
end
