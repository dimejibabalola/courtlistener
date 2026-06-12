class CreateResearchActivity < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :query, null: false
      t.jsonb :filters, null: false, default: {}
      t.boolean :alerts_enabled, null: false, default: false
      t.datetime :last_run_at
      t.integer :last_results_count
      t.jsonb :seen_document_ids, null: false, default: []
      t.timestamps
    end

    create_table :search_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :query, null: false
      t.string :query_type # citation / boolean / natural
      t.jsonb :filters, null: false, default: {}
      t.integer :results_count
      t.timestamps
    end
    add_index :search_histories, [:user_id, :created_at]

    create_table :document_views do |t|
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.integer :views_count, null: false, default: 1
      t.datetime :last_viewed_at, null: false
      t.timestamps
    end
    add_index :document_views, [:user_id, :document_id], unique: true
    add_index :document_views, [:user_id, :last_viewed_at]

    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.string :title, null: false
      t.text :body
      t.string :url
      t.jsonb :payload, null: false, default: {}
      t.datetime :read_at
      t.timestamps
    end
    add_index :notifications, [:user_id, :read_at]
  end
end
