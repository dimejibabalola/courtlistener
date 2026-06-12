class CitingReference < ApplicationRecord
  belongs_to :citing_document, class_name: "Document"
  belongs_to :cited_document, class_name: "Document"

  # Enum values are grouped by tens so classification is a value/10 bucket:
  # 0x positive/neutral, 1x cautionary, 2x negative.
  enum :treatment, {
    cited: 0, cited_favorably: 1, followed: 2, affirmed: 3, explained: 4,
    distinguished: 10, limited: 11, criticized: 12, questioned: 13, called_into_doubt: 14,
    overruled: 20, reversed: 21, vacated: 22, abrogated: 23, superseded: 24
  }, default: :cited

  enum :depth, { passing: 1, discussed: 2, significant: 3, extended: 4 }, default: :passing

  validates :citing_document_id, uniqueness: { scope: :cited_document_id }
  validate :no_self_citation

  after_create_commit :apply_counters, :schedule_treatment_recompute
  after_destroy_commit :revert_counters, :schedule_treatment_recompute
  after_update_commit :schedule_treatment_recompute, if: :saved_change_to_treatment?

  scope :negative, -> { where(treatment: negative_treatments) }
  scope :cautionary, -> { where(treatment: cautionary_treatments) }
  scope :positive, -> { where(treatment: positive_treatments) }

  def self.positive_treatments = treatments.select { |_, v| v < 10 }.keys
  def self.cautionary_treatments = treatments.select { |_, v| (10...20).cover?(v) }.keys
  def self.negative_treatments = treatments.select { |_, v| v >= 20 }.keys

  def self.treatments_for(classification)
    case classification.to_s
    when "positive" then positive_treatments
    when "cautionary" then cautionary_treatments
    when "negative" then negative_treatments
    else []
    end
  end

  # :positive, :cautionary or :negative
  def classification
    Citator::TreatmentResolver.classify(treatment)
  end

  def treatment_label = treatment.humanize

  private

  def no_self_citation
    errors.add(:cited_document, "cannot equal citing document") if citing_document_id == cited_document_id
  end

  def apply_counters
    Document.update_counters(cited_document_id, cited_by_count: 1)
    Document.update_counters(citing_document_id, cites_count: 1)
  end

  def revert_counters
    Document.update_counters(cited_document_id, cited_by_count: -1)
    Document.update_counters(citing_document_id, cites_count: -1)
  end

  def schedule_treatment_recompute
    Citator::RecomputeTreatmentJob.perform_later(cited_document_id)
  end
end
