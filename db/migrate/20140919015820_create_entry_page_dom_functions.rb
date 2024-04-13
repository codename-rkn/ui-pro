class CreateEntryPageDomFunctions < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_page_dom_functions do |t|
            t.binary :source
            t.binary :arguments
            t.text :name
            t.belongs_to :with_dom_function, polymorphic: true, index: {
                name: :entry_page_dom_functions_poly_index
            }

            t.timestamps
        end

        add_index :entry_page_dom_functions, :name
    end
end
