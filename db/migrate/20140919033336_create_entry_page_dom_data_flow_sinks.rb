class CreateEntryPageDomDataFlowSinks < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_page_dom_data_flow_sinks do |t|
            t.text :object
            t.integer :tainted_argument_index
            t.binary :tainted_value
            t.binary :taint_value
            t.belongs_to :entry_page_dom, index: true

            t.timestamps
        end

        add_index :entry_page_dom_data_flow_sinks, :object
    end
end
