class Note < ApplicationRecord
    belongs_to :entry
    has_many :attachments
end
