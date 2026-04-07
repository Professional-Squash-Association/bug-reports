class AddWebhookSecretToApiKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :api_keys, :webhook_secret, :string, null: false, default: ""
  end
end
