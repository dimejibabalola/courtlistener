class CreateWorkspace < ActiveRecord::Migration[8.1]
  def change
    create_table :matters do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, foreign_key: true
      t.string :name, null: false
      t.string :matter_number
      t.text :description
      t.integer :status, null: false, default: 0 # active / closed
      t.datetime :archived_at
      t.datetime :trashed_at
      t.timestamps
    end

    create_table :folders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :matter, foreign_key: true
      t.references :parent, foreign_key: { to_table: :folders }
      t.string :name, null: false
      t.boolean :shared, null: false, default: false
      t.integer :items_count, null: false, default: 0
      t.datetime :archived_at
      t.datetime :trashed_at
      t.timestamps
    end

    create_table :folder_items do |t|
      t.references :folder, null: false, foreign_key: true
      t.references :item, polymorphic: true, null: false
      t.references :added_by, foreign_key: { to_table: :users }
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :folder_items, [:folder_id, :item_type, :item_id], unique: true

    create_table :annotations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0 # note / highlight
      t.text :quote
      t.text :body
      t.string :color, null: false, default: "yellow"
      t.integer :start_offset
      t.integer :end_offset
      t.timestamps
    end
    add_index :annotations, [:document_id, :user_id]

    create_table :pins do |t|
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :pins, [:user_id, :document_id], unique: true

    create_table :drafts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :matter, foreign_key: true
      t.references :document, foreign_key: true # authority the draft started from
      t.string :title, null: false
      t.text :body
      t.string :tone, null: false, default: "neutral"
      t.datetime :archived_at
      t.datetime :trashed_at
      t.timestamps
    end
  end
end
