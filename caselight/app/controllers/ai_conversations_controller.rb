class AiConversationsController < ApplicationController
  def index
    @conversations = current_user.ai_conversations.order(updated_at: :desc)
  end

  def show
    @conversation = current_user.ai_conversations.find(params[:id])
  end

  def create
    context = find_context
    conversation = current_user.ai_conversations.create!(context:)
    if params[:question].present?
      Ai::ResearchAssistant.new(conversation).ask!(params[:question])
    end
    redirect_to conversation
  end

  private

  def find_context
    case params[:context_type]
    when "Document" then Document.find(params[:context_id])
    when "Matter" then current_user.visible_matters.find(params[:context_id])
    end
  end
end
