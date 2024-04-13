class AddMissingEntriesAssociationToRevisions < ActiveRecord::Migration[7.0]
  def change
    create_table :missing_entries_revisions, id: false do |t|
      t.belongs_to :entry
      t.belongs_to :revision
  end
end
end
