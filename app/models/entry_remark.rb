class EntryRemark < ActiveRecord::Base
    belongs_to :entry, optional: true
end
