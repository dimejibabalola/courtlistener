class AiMessage < ApplicationRecord
  belongs_to :ai_conversation

  enum :role, { user_role: 0, assistant: 1 }, default: :user_role

  validates :content, presence: true

  def source_documents
    ids = sources.filter_map { |s| s["document_id"] }
    Document.where(id: ids).index_by(&:id).values_at(*ids).compact
  end
end
