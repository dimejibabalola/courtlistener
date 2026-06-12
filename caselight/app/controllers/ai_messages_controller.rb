class AiMessagesController < ApplicationController
  def create
    @conversation = current_user.ai_conversations.find(params[:ai_conversation_id])
    question = params.dig(:ai_message, :content).to_s.strip
    if question.present?
      @message = Ai::ResearchAssistant.new(@conversation).ask!(question)
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to ai_conversation_path(@conversation) }
    end
  end
end
