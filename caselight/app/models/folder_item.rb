class FolderItem < ApplicationRecord
  belongs_to :folder, counter_cache: :items_count
  belongs_to :item, polymorphic: true
  belongs_to :added_by, class_name: "User", optional: true

  validates :item_id, uniqueness: { scope: [:folder_id, :item_type] }

  def title
    case item
    when Document then item.title
    when UploadedDocument, Draft then item.title
    else item.to_s
    end
  end
end
