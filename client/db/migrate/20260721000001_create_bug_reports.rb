# Creates the local bug_reports table. Deliberately unnamespaced so an app
# with an existing bug_reports table (from a bespoke integration) can adopt
# the engine without moving data - the guard below makes this migration a
# no-op in that case.
class CreateBugReports < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:bug_reports)

    create_table :bug_reports do |t|
      t.bigint :user_id, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "open"
      t.string :severity
      t.string :report_type, null: false, default: "bug"
      t.integer :remote_bug_report_id
      t.datetime :dismissed_at

      # All schema-driven form answers, keyed by field name. jsonb on
      # PostgreSQL, plain json elsewhere (e.g. SQLite in tests).
      if connection.adapter_name.match?(/postg/i)
        t.jsonb :responses, null: false, default: {}
      else
        t.json :responses, null: false, default: {}
      end

      t.timestamps
    end

    add_index :bug_reports, :user_id
    add_index :bug_reports, :remote_bug_report_id, unique: true
  end
end
