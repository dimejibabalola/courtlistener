# A single editorial point of law within a case, tagged into the topic
# taxonomy and embedded for semantic "find cases on this point" search.
class Headnote < ApplicationRecord
  has_neighbors :embedding

  belongs_to :document, counter_cache: true
  has_many :headnote_topics, dependent: :destroy
  has_many :topics, through: :headnote_topics

  validates :text, presence: true
  validates :number, presence: true, uniqueness: { scope: :document_id }

  scope :embedded, -> { where.not(embedding: nil) }

  def anchor = "headnote-#{number}"
end
