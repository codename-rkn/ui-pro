class EntryPageDomDataFlowSink < ActiveRecord::Base
    belongs_to :dom, class_name: 'EntryPageDom',
               foreign_key: 'entry_page_dom_id', optional: true

    has_one  :function,    as: :with_dom_function,
             class_name: 'EntryPageDomFunction', dependent: :destroy

    has_many :stackframes, as: :with_dom_stack_frame,
             class_name: 'EntryPageDomStackFrame', dependent: :destroy

    # @return   [String, nil]
    #   Value of the tainted argument.
    def tainted_argument_value
        return if !function.arguments
        function.arguments[tainted_argument_index]
    end

    # @return   [String, nil]
    #   Name of the tainted argument.
    def tainted_argument_name
        return if !function.signature_arguments
        function.signature_arguments[tainted_argument_index]
    end

    def self.create_from_engine( sink )
        return if sink.nil?

        create(
            object:                 sink[:object],
            taint_value:            sink[:taint],
            tainted_value:          sink[:tainted_value],
            tainted_argument_index: sink[:tainted_argument_index],
            function:               EntryPageDomFunction.create_from_engine( sink[:function] ),
            stackframes:            (sink[:trace] || []).map do |frame|
                EntryPageDomStackFrame.create_from_engine( frame )
            end
        )
    end
end
