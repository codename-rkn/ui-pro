class HttpRequest < ActiveRecord::Base
    include WithCustomSerializer

    belongs_to :requestable, polymorphic: true, optional: true

    custom_serialize :headers,    Hash
    custom_serialize :parameters, Hash

    def http_method=( m )
        super m.to_s.upcase
    end

    def to_s
        raw
    end

    def self.create_from_engine( request )
        return if request.nil?
        request = request.symbolize_keys

        create(
            url:         request[:url],
            http_method: request[:method],
            body:        request[:effective_body],
            parameters:  request[:parameters],
            headers:     request[:headers],
            raw:         request[:raw]
        )
    end

end
