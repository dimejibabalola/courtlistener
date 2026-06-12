class DocumentView < ApplicationRecord
  belongs_to :user
  belongs_to :document

  scope :recent_first, -> { order(last_viewed_at: :desc) }

  def self.record!(user, document)
    view = find_or_initialize_by(user:, document:)
    view.views_count += 1 unless view.new_record?
    view.last_viewed_at = Time.current
    view.save!
    view
  end
end
