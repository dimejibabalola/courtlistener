class Organization < ApplicationRecord
  include Sluggable

  has_many :users, dependent: :nullify
  has_many :matters, dependent: :nullify

  validates :name, presence: true
end
