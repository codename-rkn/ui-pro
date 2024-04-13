class EntryPlatformType < ActiveRecord::Base
    has_many :platforms, class_name: 'EntryPlatform',
             foreign_key: 'entry_platform_type_id'
end
