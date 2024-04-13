class EntryPlatform < ActiveRecord::Base
    belongs_to :type, class_name: 'EntryPlatformType',
               foreign_key: 'entry_platform_type_id',
               optional: true

    has_and_belongs_to_many :entries
end
