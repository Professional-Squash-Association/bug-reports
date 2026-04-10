class AddReportTypeToBugReports < ActiveRecord::Migration[8.1]
  def change
    add_column :bug_reports, :report_type, :string, null: false, default: "bug"
  end
end
