class DraftsController < ApplicationController
  before_action :set_draft, except: [:index, :new, :create, :generate]

  def index
    @drafts = current_user.drafts.kept.order(updated_at: :desc)
  end

  def new
    @draft = current_user.drafts.new(matter_id: params[:matter_id], document_id: params[:document_id])
  end

  def create
    @draft = current_user.drafts.new(draft_params)
    if @draft.save
      redirect_to edit_draft_path(@draft), notice: "Draft created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @matters = current_user.visible_matters.kept.order(:name)
  end

  def update
    @draft.update!(draft_params)
    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to edit_draft_path(@draft), notice: "Saved." }
    end
  end

  def destroy
    @draft.trash!
    redirect_to drafts_path, notice: "Draft moved to trash."
  end

  # Drafting Assistant: produce a grounded paragraph for an authority in the
  # requested tone (used by the Insert button in the reader/draft panes).
  def generate
    document = Document.find_by!(slug: params[:document_slug])
    tone = params[:tone].presence_in(Draft::TONES) || "neutral"
    paragraph = Ai::DraftingAssistant.new(current_user).paragraph_for(document, tone:)
    render json: { paragraph: paragraph }
  end

  def archive
    @draft.archive!
    redirect_to drafts_path, notice: "Draft archived."
  end

  def trash
    @draft.trash!
    redirect_to drafts_path, notice: "Draft moved to trash."
  end

  def restore
    @draft.restore!
    redirect_back_or_to drafts_path, notice: "Draft restored."
  end

  private

  def set_draft
    @draft = current_user.drafts.find(params[:id])
  end

  def draft_params
    params.require(:draft).permit(:title, :body, :tone, :matter_id, :document_id)
  end
end
