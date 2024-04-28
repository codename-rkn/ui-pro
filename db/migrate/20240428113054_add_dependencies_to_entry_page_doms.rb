class AddDependenciesToEntryPageDoms < ActiveRecord::Migration[7.0]
  def change
    add_column :entry_page_doms, :dependencies, :binary
  end
end
