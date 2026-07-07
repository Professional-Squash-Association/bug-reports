class AddReporterExternalToBugReports < ActiveRecord::Migration[8.1]
  def change
    add_column :bug_reports, :reporter_external, :boolean, null: false, default: false
  end
end
