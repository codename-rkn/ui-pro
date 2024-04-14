class CreateAttachments < ActiveRecord::Migration[7.0]
  def change
    create_table :attachments do |t|
      t.text :name
      t.blob :contents
      t.string :content_type
      t.belongs_to :note

      t.timestamps
    end
  end
end
