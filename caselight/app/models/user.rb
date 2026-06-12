class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :organization, optional: true

  has_many :saved_searches, dependent: :destroy
  has_many :search_histories, dependent: :destroy
  has_many :document_views, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :matters, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :annotations, dependent: :destroy
  has_many :pins, dependent: :destroy
  has_many :drafts, dependent: :destroy
  has_many :uploaded_documents, dependent: :destroy
  has_many :brief_analyses, dependent: :destroy
  has_many :ai_conversations, dependent: :destroy

  enum :role, { member: 0, admin: 1 }, default: :member

  encrypts :anthropic_api_key
  encrypts :openai_api_key
  encrypts :deepseek_api_key

  validates :full_name, presence: true
  validates :ai_provider, inclusion: { in: ->(_) { Ai::Providers.available_keys } }

  # Matters shared across the user's organization (firm workspace).
  def visible_matters
    return Matter.where(user: self) if organization_id.nil?

    Matter.where(user: self).or(Matter.where(organization_id:))
  end

  def visible_folders
    base = Folder.where(user: self)
    return base if organization_id.nil?

    base.or(Folder.where(shared: true, user_id: organization.user_ids))
  end

  def initials
    parts = full_name.split
    return email[0, 2].upcase if parts.empty?

    parts.first(2).map { |p| p[0] }.join.upcase
  end

  def first_name = full_name.split.first.presence || email.split("@").first

  def unread_notifications_count
    notifications.unread.count
  end

  def setting(key, default = nil)
    settings.fetch(key.to_s, default)
  end

  def update_setting!(key, value)
    update!(settings: settings.merge(key.to_s => value))
  end

  def api_key_for(provider)
    case provider.to_s
    when "anthropic" then anthropic_api_key.presence || ENV["ANTHROPIC_API_KEY"]
    when "openai" then openai_api_key.presence || ENV["OPENAI_API_KEY"]
    when "deepseek" then deepseek_api_key.presence || ENV["DEEPSEEK_API_KEY"]
    end
  end
end
