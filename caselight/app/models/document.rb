class Document < ApplicationRecord
  include Sluggable
  slug_source :title

  TYPES = %w[Case Statute Regulation SecondarySource].freeze

  belongs_to :jurisdiction, optional: true
  belongs_to :court, optional: true
  belongs_to :lower_court, class_name: "Court", optional: true
  belongs_to :primary_topic, class_name: "Topic", optional: true
  belongs_to :author_judge, class_name: "Judge", optional: true

  has_many :citations, dependent: :destroy
  has_many :headnotes, -> { order(:number) }, dependent: :destroy, inverse_of: :document
  has_many :chunks, -> { order(:position) }, class_name: "DocumentChunk",
           dependent: :destroy, inverse_of: :document

  # Outbound edges: authorities this document cites.
  has_many :outbound_references, class_name: "CitingReference",
           foreign_key: :citing_document_id, dependent: :destroy, inverse_of: :citing_document
  has_many :cited_documents, through: :outbound_references, source: :cited_document

  # Inbound edges: later documents citing this one. Treatment comes from here.
  has_many :inbound_references, class_name: "CitingReference",
           foreign_key: :cited_document_id, dependent: :destroy, inverse_of: :cited_document
  has_many :citing_documents, through: :inbound_references, source: :citing_document

  has_many :case_judges, dependent: :destroy
  has_many :judges, through: :case_judges
  has_many :case_attorneys, dependent: :destroy
  has_many :attorneys, through: :case_attorneys
  has_many :case_parties, dependent: :destroy
  has_many :parties, through: :case_parties

  has_many :annotations, dependent: :destroy
  has_many :document_views, dependent: :destroy
  has_many :pins, dependent: :destroy
  has_many :folder_items, as: :item, dependent: :destroy
  has_many :drafts, dependent: :nullify

  # Denormalized worst-inbound-treatment signal; see Citator::TreatmentResolver.
  enum :treatment_status, { untreated: 0, positive: 1, cautionary: 2, negative: 3 },
       default: :untreated

  validates :title, presence: true
  validates :type, inclusion: { in: TYPES }

  scope :by_recency, -> { order(decided_on: :desc, id: :desc) }
  scope :most_cited, -> { order(cited_by_count: :desc, id: :desc) }
  scope :decided_between, ->(from, to) {
    rel = all
    rel = rel.where(decided_on: from..) if from.present?
    rel = rel.where(decided_on: ..to) if to.present?
    rel
  }

  def self.find_by_citation(raw)
    Citation.lookup(raw)&.document
  end

  def display_citation
    primary_citation.presence || citations.first&.raw
  end

  def parallel_citations
    citations.map(&:raw) - [display_citation]
  end

  def court_line
    [court&.short_name, decided_on&.strftime("%b %-d, %Y")].compact.join(" • ")
  end

  def treatment_badge
    Citator::TreatmentResolver.badge_for(treatment_status)
  end

  def doc_type_label = model_name.human

  def recompute_treatment!
    Citator::TreatmentResolver.new(self).resolve!
  end

  def reading_text
    full_text.presence || summary.to_s
  end

  # Notes / highlights count shown in the reader tabs for the current user.
  def notes_for(user)
    annotations.where(user:).order(created_at: :desc)
  end
end
