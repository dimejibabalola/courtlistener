class AiConversation < ApplicationRecord
  belongs_to :user
  belongs_to :context, polymorphic: true, optional: true
  has_many :ai_messages, -> { order(:created_at, :id) }, dependent: :destroy,
           inverse_of: :ai_conversation

  def display_title
    title.presence || ai_messages.user_role.first&.content&.truncate(60) || "New conversation"
  end
end
