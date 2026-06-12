class MattersController < ApplicationController
  before_action :set_matter, except: [:index, :new, :create]

  def index
    @matters = current_user.visible_matters.kept.order(updated_at: :desc)
  end

  def show
    @folders = @matter.folders.kept.order(:name)
    @uploads = @matter.uploaded_documents.kept.order(created_at: :desc)
    @drafts = @matter.drafts.kept.order(updated_at: :desc)
    @conversation = @matter.ai_conversations.order(created_at: :desc).first
  end

  def new
    @matter = current_user.matters.new
  end

  def create
    @matter = current_user.matters.new(matter_params)
    @matter.organization = current_user.organization if params.dig(:matter, :shared) == "1"
    if @matter.save
      redirect_to @matter, notice: "Matter created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @matter.update(matter_params)
      redirect_to @matter, notice: "Matter updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @matter.trash!
    redirect_to matters_path, notice: "Matter moved to trash."
  end

  def archive
    @matter.archive!
    redirect_to matters_path, notice: "Matter archived."
  end

  def unarchive
    @matter.unarchive!
    redirect_back_or_to matters_path, notice: "Matter restored to active."
  end

  def trash
    @matter.trash!
    redirect_to matters_path, notice: "Matter moved to trash."
  end

  def restore
    @matter.restore!
    redirect_back_or_to matters_path, notice: "Matter restored."
  end

  private

  def set_matter
    @matter = current_user.visible_matters.find(params[:id])
  end

  def matter_params
    params.require(:matter).permit(:name, :matter_number, :description, :status)
  end
end
