# Error reports (automatic 500 capture from consuming apps) are deduplicated
# by fingerprint: repeats of the same error bump occurrence_count on the open
# report instead of filing duplicate GitHub issues.
class AddErrorTrackingToBugReports < ActiveRecord::Migration[8.1]
  def change
    add_column :bug_reports, :fingerprint, :string
    add_column :bug_reports, :occurrence_count, :integer, null: false, default: 1
    add_column :bug_reports, :last_occurred_at, :datetime

    add_index :bug_reports, [ :source, :fingerprint ]

    # Error reports are machine-generated: no human reporter. Presence for
    # user-submitted reports is still enforced at the model level.
    change_column_null :bug_reports, :reporter_email, true
  end
end
