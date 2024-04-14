class EntryPageDomExecutionFlowSink < ActiveRecord::Base
    include WithCustomSerializer

    belongs_to :dom, class_name: 'EntryPageDom',
               foreign_key: 'entry_page_dom_id',
               optional: true

    has_many :stackframes, as: :with_dom_stack_frame,
             class_name: 'EntryPageDomStackFrame', dependent: :destroy

    custom_serialize :data, Array

    def self.create_from_engine( sink )
        sink = sink.symbolize_keys
        create(
            data:        sink[:data],
            stackframes: sink[:trace].map do |frame|
                EntryPageDomStackFrame.create_from_engine( frame )
            end
        )
    end
end
