class EntryPageDom < ActiveRecord::Base
    belongs_to :page, class_name: 'EntryPage', foreign_key: 'entry_page_id',
               optional: true

    has_many :transitions,          class_name: 'EntryPageDomTransition',
             dependent: :destroy

    has_many :data_flow_sinks,      class_name: 'EntryPageDomDataFlowSink',
             dependent: :destroy

    def self.create_from_engine( dom )
        dom = dom.symbolize_keys
        create(
            url:                  dom[:url],
            body:                 dom[:body],
            transitions:          dom[:transitions].map do |transition|
                EntryPageDomTransition.create_from_engine( transition )
            end,
            data_flow_sinks:      dom[:data_flow_sinks].map do |sink|
                EntryPageDomDataFlowSink.create_from_engine( sink )
            end
        )
    end
end
