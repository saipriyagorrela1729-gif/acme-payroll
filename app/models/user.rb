class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  before_validation :ensure_api_token, on: :create

  # Rotates the token (used on logout so a stolen token stops working).
  def regenerate_api_token!
    update!(api_token: generate_token)
  end

  def self.authenticate(email:, password:)
    user = find_by(email: email.to_s.strip.downcase)
    return nil unless user

    user.authenticate(password) || nil
  end

  private

  def ensure_api_token
    self.api_token ||= generate_token
  end

  def generate_token
    SecureRandom.hex(24)
  end
end
