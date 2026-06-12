module Sluggable
  extend ActiveSupport::Concern

  included do
    class_attribute :slug_source_attribute, default: :name, instance_writer: false
    before_validation :assign_slug, on: :create
    validates :slug, presence: true, uniqueness: true
  end

  class_methods do
    def slug_source(attribute)
      self.slug_source_attribute = attribute
    end
  end

  def to_param = slug

  private

  def assign_slug
    return if slug.present?

    base = public_send(self.class.slug_source_attribute).to_s.parameterize[0, 80]
    base = SecureRandom.hex(4) if base.blank?
    candidate = base
    n = 1
    candidate = "#{base}-#{n += 1}" while self.class.base_class.unscoped.exists?(slug: candidate)
    self.slug = candidate
  end
end
