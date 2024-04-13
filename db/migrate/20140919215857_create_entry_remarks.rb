class CreateEntryRemarks < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_remarks do |t|
            t.string :author
            t.text :text
            t.belongs_to :entry, index: true

            t.timestamps
        end
    end
end
