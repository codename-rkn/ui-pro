class AddDataToReports < ActiveRecord::Migration[7.0]
  def change
    add_column :reports, :data, :json
  end
end
