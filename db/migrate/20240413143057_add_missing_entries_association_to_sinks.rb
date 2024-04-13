class AddMissingEntriesAssociationToSinks < ActiveRecord::Migration[7.0]
  def change
    create_table :entries_entry_sinks, id: false do |t|
      t.belongs_to :entry
      t.belongs_to :entry_sink
    end
  end
end
