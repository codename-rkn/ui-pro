class InputVector < ActiveRecord::Base
    include WithCustomSerializer

    belongs_to :sitemap_entry, counter_cache: true, optional: true

    custom_serialize :inputs,         Hash
    custom_serialize :default_inputs, Hash

    def kind
        super.to_sym
    end

    def http_method=( m )
        super m.to_s.upcase
    end

    def engine_class
        SCNR::Engine::Element.const_get(
            super.gsub( 'SCNR::Engine::Element::', '' ).split( '::' ).first.to_sym
        )
    end

    def to_s
        kind.to_s.gsub( '_', ' ' ).sub( 'dom', 'DOM' ).sub( 'ui', 'UI' )
    end

    def self.create_from_engine( vector, options = {}  )
        h = {}
        [:action, :http_method, :seed, :inputs, :affected_input_name, :source,
         :default_inputs].each do |attr|
            h[attr] = vector[attr]
        end

        h[:kind]         = vector[:type]
        h[:engine_class] = vector[:class]

        create h.merge( options )
    end

end
