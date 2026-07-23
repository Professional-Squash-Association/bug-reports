# Human-readable description of what the user was doing when the error was
# captured ("viewing invoices") - shown on the report form instead of the
# technical exception details.
class AddActivityToBugReportErrorEvents < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:bug_report_error_events, :activity)

    add_column :bug_report_error_events, :activity, :string
  end
end
