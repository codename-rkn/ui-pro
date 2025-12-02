class AddTimezoneToSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :settings, :timezone, :string
  end
end
