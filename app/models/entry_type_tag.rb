class EntryTypeTag < ActiveRecord::Base
    has_and_belongs_to_many :types, class_name: 'EntryType',
        foreign_key: 'entry_type_id',
        join_table: 'entry_types_entry_type_tags'
end
