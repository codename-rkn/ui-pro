class EntryPageDomTransition < ActiveRecord::Base
    include WithCustomSerializer

    custom_serialize :options, Hash

    belongs_to :dom, class_name: 'EntryPageDom',
               foreign_key: 'entry_page_dom_id',
               optional: true

    def event
        super.to_sym if super
    end

    def self.create_from_engine( transition )
        transition = transition.symbolize_keys
        create(
            element: transition[:element].is_a?( String ) ? transition[:element] : transition[:element]['source'],
            event:   transition[:event],
            time:    transition[:time],
            options: transition[:options]
        )
    end
end
