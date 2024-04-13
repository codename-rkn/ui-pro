class EntryType < ActiveRecord::Base
    has_and_belongs_to_many :tags, class_name: 'EntryTypeTag',
             foreign_key: 'entry_type_tag_id',
             join_table: 'entry_types_entry_type_tags'

    has_many :references, class_name: 'EntryTypeReference',
             foreign_key: 'entry_type_id', dependent: :destroy

    has_many :entries

end
