class CreateBugReports < ActiveRecord::Migration[8.1]
  def change
    create_table :bug_reports do |t|
      t.string :title, null: false
      t.text :description
      t.text :steps_to_reproduce
      t.string :severity, default: "medium"
      t.string :source, null: false
      t.string :reporter_email, null: false
      t.string :reporter_name
      t.string :status, default: "pending"
      t.string :image_url
      t.string :callback_url
      t.string :github_issue_url
      t.integer :github_issue_number
      t.string :github_repo

      t.timestamps
    end

    create_table :api_keys do |t|
      t.string :token, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :api_keys, :token, unique: true
  end
end
