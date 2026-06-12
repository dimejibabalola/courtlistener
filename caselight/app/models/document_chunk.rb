# Passage of a document, embedded into pgvector for semantic retrieval and
# for grounding AI answers in quotable source text.
class DocumentChunk < ApplicationRecord
  has_neighbors :embedding

  belongs_to :document

  validates :content, presence: true
  validates :position, uniqueness: { scope: :document_id }

  scope :embedded, -> { where.not(embedding: nil) }
end
