class SavedSearch < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :query, presence: true

  scope :alertable, -> { where(alerts_enabled: true) }

  def record_run!(result_ids)
    update!(
      last_run_at: Time.current,
      last_results_count: result_ids.size,
      seen_document_ids: (seen_document_ids | result_ids).last(5_000)
    )
  end

  def new_result_ids(result_ids)
    result_ids - seen_document_ids
  end
end
