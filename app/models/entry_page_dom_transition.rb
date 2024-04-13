class EntryPageDomTransition < ActiveRecord::Base
    include WithCustomSerializer

    custom_serialize :options, Hash

    belongs_to :dom, class_name: 'EntryPageDom',
               foreign_key: 'entry_page_dom_id',
               optional: true

    def event
        super.to_sym
    end

    def self.create_from_engine( transition )
        create(
            element: transition[:element].to_s,
            event:   transition[:event],
            time:    transition[:time],
            options: transition[:options]
        )
    end
end
