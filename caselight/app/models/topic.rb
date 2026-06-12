# Node in the hierarchical legal-topic taxonomy: area -> topic -> point of law.
# Codes are original to this project (e.g. "BUS.CORP.VEIL.020").
class Topic < ApplicationRecord
  belongs_to :parent, class_name: "Topic", optional: true
  has_many :children, -> { order(:position) }, class_name: "Topic",
           foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
  has_many :headnote_topics, dependent: :destroy
  has_many :headnotes, through: :headnote_topics
  has_many :primary_documents, class_name: "Document", foreign_key: :primary_topic_id,
           dependent: :nullify, inverse_of: :primary_topic

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true

  scope :roots, -> { where(parent_id: nil).order(:position) }
  scope :leaves, -> { where.missing(:children) }

  def root? = parent_id.nil?
  def leaf? = children.empty?

  def ancestors
    node = self
    chain = []
    chain.unshift(node = node.parent) while node.parent_id
    chain
  end

  def path_names = (ancestors + [self]).map(&:name)

  def self_and_descendant_ids
    self.class.connection.select_values(<<~SQL)
      WITH RECURSIVE tree AS (
        SELECT id FROM topics WHERE id = #{id.to_i}
        UNION ALL
        SELECT t.id FROM topics t JOIN tree ON t.parent_id = tree.id
      )
      SELECT id FROM tree
    SQL
  end

  # Every headnote tagged at or below this node.
  def headnotes_in_subtree
    Headnote.joins(:headnote_topics).where(headnote_topics: { topic_id: self_and_descendant_ids }).distinct
  end
end
