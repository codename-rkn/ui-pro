class CreateInputVectors < ActiveRecord::Migration[5.1]
    def change
        create_table :input_vectors do |t|
            t.binary :default_inputs
            t.binary :inputs
            t.text :seed
            t.string :engine_class
            t.string :kind
            t.text :action
            t.text :source
            t.string :http_method
            t.text :affected_input_name
            t.belongs_to :sitemap_entry
            t.belongs_to :entry

            t.timestamps
        end

        add_index :input_vectors, :kind
    end
end
