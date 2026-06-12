class Court < ApplicationRecord
  include Sluggable

  belongs_to :jurisdiction
  belongs_to :parent, class_name: "Court", optional: true
  has_many :children, class_name: "Court", foreign_key: :parent_id,
           inverse_of: :parent, dependent: :destroy
  has_many :documents, dependent: :nullify
  has_many :judges, dependent: :nullify

  enum :level, { trial: 0, appellate: 1, supreme: 2 }, default: :trial

  validates :name, presence: true

  def short_name = abbreviation.presence || name
end
