class UploadedDocumentsController < ApplicationController
  before_action :set_upload, except: [:index, :new, :create]

  def index
    @uploads = current_user.uploaded_documents.kept.order(created_at: :desc)
    @uploads = @uploads.search_text(params[:q]) if params[:q].present?
    @uploads = @uploads.where(kind: params[:kind]) if params[:kind].present?
  end

  def show
    @analysis = @upload.latest_analysis
  end

  def new
    @upload = current_user.uploaded_documents.new(kind: params[:kind] || :brief, matter_id: params[:matter_id])
    @matters = current_user.visible_matters.kept.order(:name)
  end

  def create
    @upload = current_user.uploaded_documents.new(upload_params)
    @upload.title = @upload.file.filename.to_s if @upload.title.blank? && @upload.file.attached?
    if @upload.save
      Uploads::ExtractTextJob.perform_later(@upload.id)
      redirect_to upload_path(@upload), notice: "Uploaded. Text extraction is running."
    else
      @matters = current_user.visible_matters.kept.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @upload.update!(upload_params.except(:file))
    redirect_to upload_path(@upload), notice: "Updated."
  end

  def destroy
    @upload.trash!
    redirect_to uploads_path, notice: "Moved to trash."
  end

  def reprocess
    Uploads::ExtractTextJob.perform_later(@upload.id)
    redirect_to upload_path(@upload), notice: "Re-running extraction."
  end

  def archive
    @upload.archive!
    redirect_to uploads_path, notice: "Archived."
  end

  def trash
    @upload.trash!
    redirect_to uploads_path, notice: "Moved to trash."
  end

  def restore
    @upload.restore!
    redirect_back_or_to uploads_path, notice: "Restored."
  end

  private

  def set_upload
    @upload = current_user.uploaded_documents.find(params[:id])
  end

  def upload_params
    params.require(:uploaded_document).permit(:title, :kind, :matter_id, :file)
  end
end
