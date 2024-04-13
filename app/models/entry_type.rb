class EntryType < ActiveRecord::Base
    belongs_to :severity, class_name: 'EntryTypeSeverity',
             foreign_key: 'entry_type_severity_id', optional: true

    has_and_belongs_to_many :tags, class_name: 'EntryTypeTag',
             foreign_key: 'entry_type_tag_id',
             join_table: 'entry_types_entry_type_tags'

    has_many :references, class_name: 'EntryTypeReference',
             foreign_key: 'entry_type_id', dependent: :destroy

    has_many :entries

    scope :by_severity, -> do
        includes(:severity).joins(:severity).
          order( EntryTypeSeverity.order_sql ).order(name: :asc)
    end
    # default_scope { by_severity }

    def cwe_url
        return if !cwe
        "http://cwe.mitre.org/data/definitions/#{cwe}.html"
    end

end
