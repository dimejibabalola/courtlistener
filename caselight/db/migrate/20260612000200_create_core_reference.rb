class CreateCoreReference < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.timestamps
    end

    create_table :jurisdictions do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.integer :kind, null: false, default: 0 # federal / state
      t.references :parent, foreign_key: { to_table: :jurisdictions }
      t.timestamps
    end

    create_table :courts do |t|
      t.string :name, null: false
      t.string :abbreviation
      t.string :slug, null: false, index: { unique: true }
      t.integer :level, null: false, default: 0 # trial / appellate / supreme
      t.references :jurisdiction, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :courts }
      t.timestamps
    end

    # Hierarchical legal-topic taxonomy (original codes, key-number style)
    create_table :topics do |t|
      t.string :name, null: false
      t.string :code, null: false, index: { unique: true } # e.g. "BUS.CORP.VEIL.020"
      t.references :parent, foreign_key: { to_table: :topics }
      t.integer :depth, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.integer :headnotes_count, null: false, default: 0
      t.timestamps
    end
    add_index :topics, [:parent_id, :position]
  end
end
