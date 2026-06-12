class UploadedDocument < ApplicationRecord
  include SoftDeletable
  include PgSearch::Model

  belongs_to :user
  belongs_to :matter, optional: true
  has_one_attached :file
  has_many :brief_analyses, dependent: :destroy
  has_many :folder_items, as: :item, dependent: :destroy

  enum :kind, { brief: 0, opinion: 1, contract: 2, correspondence: 3, other: 4 },
       default: :other
  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }, default: :pending

  validates :title, presence: true

  pg_search_scope :search_text,
                  against: :title, # ignored: tsvector_column takes precedence
                  using: { tsearch: { tsvector_column: "search_vector", dictionary: "english" } }

  def latest_analysis = brief_analyses.order(created_at: :desc).first

  def extracted? = extracted_text.present?

  def word_count = extracted_text.to_s.split.size
end
