class CreateEntryPageDoms < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_page_doms do |t|
            t.text :url
            t.binary :body
            t.belongs_to :entry_page, index: true

            t.timestamps
        end

        add_index :entry_page_doms, :url
    end
end
