class RemoveLocationFromReports < ActiveRecord::Migration[7.0]
  def change
    remove_column :reports, :location
  end
end
