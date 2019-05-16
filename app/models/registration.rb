class Registration < ApplicationRecord
  enum format: [:u2f, :webauthn]

  validates :name, presence: true
  validates :public_key, presence: true
  validates :key_handle, presence: true
  validates :counter, numericality: true
  validates :format, presence: true
end
