class AnnotationsController < ApplicationController
  def create
    document = Document.find_by!(slug: params[:document_slug])
    document.annotations.create!(annotation_params.merge(user: current_user))
    redirect_back_or_to document_path(document, tab: "notes"), notice: "Note saved."
  end

  def destroy
    annotation = current_user.annotations.find(params[:id])
    annotation.destroy!
    redirect_back_or_to document_path(annotation.document, tab: "notes"), notice: "Note removed."
  end

  private

  def annotation_params
    params.require(:annotation).permit(:kind, :body, :quote, :color, :start_offset, :end_offset)
  end
end
