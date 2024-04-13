class EntryTypeReference < ActiveRecord::Base
    belongs_to :types, class_name: 'EntryType',
               foreign_key: 'entry_type_id', optional: true
end
