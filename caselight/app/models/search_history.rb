class SearchHistory < ApplicationRecord
  belongs_to :user

  validates :query, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
