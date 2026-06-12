class BriefAnalysis < ApplicationRecord
  belongs_to :uploaded_document
  belongs_to :user
  has_many :brief_citations, -> { order(:position) }, dependent: :destroy,
           inverse_of: :brief_analysis

  enum :status, { pending: 0, processing: 1, complete: 2, failed: 3 }, default: :pending

  def refresh_counts!
    matched = brief_citations.matched
    update!(
      authorities_count: brief_citations.count,
      clean_count: matched.where(treatment_status: [:untreated, :positive]).count,
      cautionary_count: matched.where(treatment_status: :cautionary).count,
      negative_count: matched.where(treatment_status: :negative).count,
      unmatched_count: brief_citations.where.not(status: :matched).count
    )
  end
end
