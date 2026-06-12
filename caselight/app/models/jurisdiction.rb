class Jurisdiction < ApplicationRecord
  include Sluggable

  belongs_to :parent, class_name: "Jurisdiction", optional: true
  has_many :children, class_name: "Jurisdiction", foreign_key: :parent_id,
           inverse_of: :parent, dependent: :destroy
  has_many :courts, dependent: :destroy
  has_many :documents, dependent: :nullify

  enum :kind, { federal: 0, state: 1 }, default: :federal

  validates :name, presence: true

  scope :roots, -> { where(parent_id: nil) }
end
