class TrashController < ApplicationController
  SCOPES = {
    "Matters" => ->(user) { user.matters },
    "Folders" => ->(user) { user.folders },
    "Drafts" => ->(user) { user.drafts },
    "Uploads" => ->(user) { user.uploaded_documents }
  }.freeze

  def index
    @groups = SCOPES.transform_values { |scope| scope.call(current_user).trashed.order(trashed_at: :desc) }
  end

  def archive_index
    @groups = SCOPES.transform_values { |scope| scope.call(current_user).archived.order(archived_at: :desc) }
  end

  def empty
    SCOPES.each_value { |scope| scope.call(current_user).trashed.find_each(&:destroy!) }
    redirect_to trash_path, notice: "Trash emptied."
  end
end
