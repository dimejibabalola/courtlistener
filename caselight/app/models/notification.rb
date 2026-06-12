class Notification < ApplicationRecord
  belongs_to :user

  enum :kind, { system: 0, saved_search_alert: 1, brief_complete: 2, ocr_complete: 3 },
       default: :system

  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc) }

  def read? = read_at.present?
  def mark_read! = update!(read_at: Time.current)
end
