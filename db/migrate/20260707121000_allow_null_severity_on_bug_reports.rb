class AllowNullSeverityOnBugReports < ActiveRecord::Migration[8.1]
  def change
    change_column_null :bug_reports, :severity, true
  end
end
