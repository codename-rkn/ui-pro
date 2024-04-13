class AddMissingEntriesAssociationToPlatforms < ActiveRecord::Migration[7.0]
  def change
    create_table :entries_entry_platforms, id: false do |t|
      t.belongs_to :entry
      t.belongs_to :entry_platform
    end

  end
end
