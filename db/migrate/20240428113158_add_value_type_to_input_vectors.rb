class AddValueTypeToInputVectors < ActiveRecord::Migration[7.0]
  def change
    add_column :input_vectors, :value_type, :string, default: 'undetermined'
  end
end
