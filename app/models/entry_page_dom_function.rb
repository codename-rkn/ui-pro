class EntryPageDomFunction < ActiveRecord::Base
    include WithCustomSerializer

    belongs_to :with_dom_function, polymorphic: true, optional: true

    custom_serialize :arguments, Array

    def signature_arguments
        return [] if !signature
        signature.match( /\((.*)\)/ )[1].split( ',' ).map(&:strip)
    end

    def signature
        return if !source
        source.match( /function\s*(.*?)\s*\{/m )[1]
    end

    def self.create_from_engine( function )
        return if function.nil?

        function = function.symbolize_keys
        create(
            name:      function[:name],
            source:    function[:source],
            arguments: function[:arguments]
        )
    end
end
