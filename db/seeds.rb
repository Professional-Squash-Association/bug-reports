# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create an API key for each source app defined in the repo mapping.
RepoMapping.all_sources.each do |source|
  api_key = ApiKey.find_or_create_by!(name: source)
  puts "#{api_key.name}: token=#{api_key.token} webhook_secret=#{api_key.webhook_secret}"
end
