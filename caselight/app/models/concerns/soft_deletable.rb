# Archive (hide from active lists, keep findable) and trash (queued for
# permanent deletion, restorable until purged) semantics shared by user
# content: matters, folders, drafts, uploaded documents.
module SoftDeletable
  extend ActiveSupport::Concern

  PURGE_AFTER = 30.days

  included do
    scope :kept, -> { where(archived_at: nil, trashed_at: nil) }
    scope :archived, -> { where.not(archived_at: nil).where(trashed_at: nil) }
    scope :trashed, -> { where.not(trashed_at: nil) }
    scope :purgeable, -> { where(trashed_at: ...PURGE_AFTER.ago) }
  end

  def kept? = archived_at.nil? && trashed_at.nil?
  def archived? = archived_at.present? && trashed_at.nil?
  def trashed? = trashed_at.present?

  def archive! = update!(archived_at: Time.current)
  def unarchive! = update!(archived_at: nil)
  def trash! = update!(trashed_at: Time.current)

  def restore!
    update!(trashed_at: nil, archived_at: nil)
  end

  def days_until_purge
    return nil unless trashed?

    [((trashed_at + PURGE_AFTER - Time.current) / 1.day).ceil, 0].max
  end
end
