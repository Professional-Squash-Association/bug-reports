# Per-user log of captured 500s. When a signed-in user hits an error, an
# event is recorded against them so the bug report form can ask "did your
# problem relate to this error?" and thread the details into the report.
class CreateBugReportErrorEvents < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:bug_report_error_events)

    create_table :bug_report_error_events do |t|
      t.bigint :user_id, null: false
      t.string :fingerprint, null: false
      t.string :exception_class, null: false
      t.string :message
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :bug_report_error_events, [ :user_id, :occurred_at ]
  end
end
