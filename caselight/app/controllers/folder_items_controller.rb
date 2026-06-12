class FolderItemsController < ApplicationController
  ITEM_TYPES = { "Document" => Document, "UploadedDocument" => UploadedDocument, "Draft" => Draft }.freeze

  def create
    folder = current_user.visible_folders.find(params[:folder_id])
    item = find_item
    folder.add(item, added_by: current_user)
    redirect_back_or_to folder_path(folder), notice: "Saved to “#{folder.name}”."
  end

  def destroy
    item = FolderItem.joins(:folder).where(folders: { id: current_user.visible_folders.select(:id) })
                     .find(params[:id])
    folder = item.folder
    item.destroy!
    redirect_back_or_to folder_path(folder), notice: "Removed from folder."
  end

  private

  def find_item
    klass = ITEM_TYPES.fetch(params[:item_type])
    scope = klass == Document ? Document.all : klass.where(user: current_user)
    scope.find(params[:item_id])
  end
end
