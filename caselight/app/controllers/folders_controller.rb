class FoldersController < ApplicationController
  before_action :set_folder, except: [:index, :new, :create]

  def index
    @folders = current_user.visible_folders.kept.order(updated_at: :desc)
  end

  def show
    @items = @folder.folder_items.includes(:item, :added_by)
  end

  def new
    @folder = current_user.folders.new(matter_id: params[:matter_id])
  end

  def create
    @folder = current_user.folders.new(folder_params)
    if @folder.save
      redirect_back_or_to folder_path(@folder), notice: "Folder “#{@folder.name}” created."
    else
      redirect_back_or_to folders_path, alert: @folder.errors.full_messages.to_sentence
    end
  end

  def update
    @folder.update!(folder_params)
    redirect_to @folder, notice: "Folder updated."
  end

  def destroy
    @folder.trash!
    redirect_to folders_path, notice: "Folder moved to trash."
  end

  def archive
    @folder.archive!
    redirect_to folders_path, notice: "Folder archived."
  end

  def trash
    @folder.trash!
    redirect_to folders_path, notice: "Folder moved to trash."
  end

  def restore
    @folder.restore!
    redirect_back_or_to folders_path, notice: "Folder restored."
  end

  private

  def set_folder
    @folder = current_user.visible_folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :matter_id, :shared, :parent_id)
  end
end
