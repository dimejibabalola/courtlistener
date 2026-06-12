# A client/matter workspace bundling folders, uploads, drafts and AI research.
class Matter < ApplicationRecord
  include SoftDeletable

  belongs_to :user
  belongs_to :organization, optional: true

  has_many :folders, dependent: :nullify
  has_many :uploaded_documents, dependent: :nullify
  has_many :drafts, dependent: :nullify
  has_many :ai_conversations, as: :context, dependent: :destroy

  enum :status, { active: 0, closed: 1 }, default: :active

  validates :name, presence: true

  def documents_count = folders.kept.sum(:items_count) + uploaded_documents.kept.count
end
