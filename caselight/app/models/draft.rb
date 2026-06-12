class Draft < ApplicationRecord
  include SoftDeletable

  TONES = %w[neutral persuasive formal plain].freeze

  belongs_to :user
  belongs_to :matter, optional: true
  belongs_to :document, optional: true
  has_many :folder_items, as: :item, dependent: :destroy

  validates :title, presence: true
  validates :tone, inclusion: { in: TONES }

  def excerpt(length = 160)
    ActionController::Base.helpers.strip_tags(body.to_s).squish.truncate(length)
  end
end
