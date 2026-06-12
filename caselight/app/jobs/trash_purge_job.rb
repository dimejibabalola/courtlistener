# Permanently deletes trashed items older than the retention window.
# Schedule daily.
class TrashPurgeJob < ApplicationJob
  queue_as :maintenance

  PURGEABLE = [Matter, Folder, Draft, UploadedDocument].freeze

  def perform
    PURGEABLE.each { |klass| klass.purgeable.find_each(&:destroy!) }
  end
end
