# One authority extracted from an uploaded brief, possibly resolved to a
# Document in the corpus, with the treatment snapshot taken at analysis time.
class BriefCitation < ApplicationRecord
  belongs_to :brief_analysis
  belongs_to :document, optional: true
  belongs_to :resolved_from, class_name: "BriefCitation", optional: true

  enum :kind, {
    case_full: 0, case_short: 1, id_cite: 2, supra_cite: 3,
    statute: 4, regulation: 5, unknown: 6
  }, default: :unknown

  enum :status, { matched: 0, unmatched: 1, needs_review: 2 }, default: :unmatched
  enum :treatment_status, { untreated: 0, positive: 1, cautionary: 2, negative: 3 },
       default: :untreated, prefix: :treatment

  validates :raw_cite, presence: true

  # clean / cautionary / negative / unmatched, for the table of authorities.
  def authority_status
    return "unmatched" unless matched?

    case treatment_status
    when "negative" then "negative"
    when "cautionary" then "cautionary"
    else "clean"
    end
  end
end
