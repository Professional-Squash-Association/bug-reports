# Dummy app schema: a host User table, Active Storage tables, and the
# engine's bug_reports table (kept in step with db/migrate in the engine).
ActiveRecord::Schema[8.0].define do
  create_table :users, force: true do |t|
    t.string :email, null: false
    t.string :name
    t.boolean :admin, null: false, default: false
    t.timestamps
  end

  create_table :bug_reports, force: true do |t|
    t.bigint :user_id, null: false
    t.string :title, null: false
    t.string :status, null: false, default: "open"
    t.string :severity
    t.string :report_type, null: false, default: "bug"
    t.integer :remote_bug_report_id
    t.datetime :dismissed_at
    t.json :responses, null: false, default: {}
    t.timestamps

    t.index :user_id
    t.index :remote_bug_report_id, unique: true
  end

  create_table :bug_report_error_events, force: true do |t|
    t.bigint :user_id, null: false
    t.string :fingerprint, null: false
    t.string :exception_class, null: false
    t.string :message
    t.string :activity
    t.datetime :occurred_at, null: false
    t.timestamps

    t.index [ :user_id, :occurred_at ]
  end

  create_table :active_storage_blobs, force: true do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.datetime :created_at, null: false

    t.index [ :key ], unique: true
  end

  create_table :active_storage_attachments, force: true do |t|
    t.string :name, null: false
    t.string :record_type, null: false
    t.bigint :record_id, null: false
    t.bigint :blob_id, null: false
    t.datetime :created_at, null: false

    t.index [ :record_type, :record_id, :name, :blob_id ], name: "index_active_storage_attachments_uniqueness", unique: true
    t.index [ :blob_id ]
  end

  create_table :active_storage_variant_records, force: true do |t|
    t.bigint :blob_id, null: false
    t.string :variation_digest, null: false

    t.index [ :blob_id, :variation_digest ], name: "index_active_storage_variant_records_uniqueness", unique: true
  end
end
