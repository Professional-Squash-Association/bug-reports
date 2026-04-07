class CreateBugReports < ActiveRecord::Migration[8.1]
  def change
    create_table :bug_reports do |t|
      t.string :title
      t.text :description
      t.text :steps_to_reproduce
      t.string :severity
      t.string :source
      t.string :reporter_email
      t.string :reporter_name
      t.string :status
      t.string :github_issue_url
      t.integer :github_issue_number
      t.string :github_repo

      t.timestamps
    end
  end
end
