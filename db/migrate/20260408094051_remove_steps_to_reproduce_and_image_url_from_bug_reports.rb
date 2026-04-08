class RemoveStepsToReproduceAndImageUrlFromBugReports < ActiveRecord::Migration[8.1]
  def change
    remove_column :bug_reports, :steps_to_reproduce, :text
    remove_column :bug_reports, :image_url, :string
  end
end
