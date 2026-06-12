class AddDeepseekKeyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :deepseek_api_key, :text # encrypted via Active Record encryption
  end
end
