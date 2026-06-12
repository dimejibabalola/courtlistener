class Folder < ApplicationRecord
  include SoftDeletable

  belongs_to :user
  belongs_to :matter, optional: true
  belongs_to :parent, class_name: "Folder", optional: true
  has_many :children, class_name: "Folder", foreign_key: :parent_id,
           inverse_of: :parent, dependent: :destroy
  has_many :folder_items, -> { order(:position) }, dependent: :destroy, inverse_of: :folder

  validates :name, presence: true

  def contains?(item)
    folder_items.exists?(item:)
  end

  def add(item, added_by: nil)
    folder_items.create_or_find_by!(item:) do |fi|
      fi.added_by = added_by
      fi.position = (folder_items.maximum(:position) || 0) + 1
    end
  end
end
