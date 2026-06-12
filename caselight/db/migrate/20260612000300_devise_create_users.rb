class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Profile / workspace
      t.string :full_name, null: false, default: ""
      t.integer :role, null: false, default: 0 # member / admin
      t.references :organization, foreign_key: true

      ## AI provider preferences (model-provider switching)
      t.string :ai_provider, null: false, default: "local"
      t.string :ai_model
      t.text :anthropic_api_key # encrypted via Active Record encryption
      t.text :openai_api_key    # encrypted via Active Record encryption

      ## UI preferences (sidebar collapse, theme, default scope, ...)
      t.jsonb :settings, null: false, default: {}

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
  end
end
