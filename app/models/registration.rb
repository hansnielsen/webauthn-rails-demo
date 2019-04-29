class Registration < ApplicationRecord
  validates :name, presence: true
  validates :public_key, presence: true
  validates :key_handle, presence: true
  validates :counter, numericality: true
end
