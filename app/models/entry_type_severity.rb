class EntryTypeSeverity < ActiveRecord::Base
    has_many :types, class_name: 'EntryType'
    has_many :entries, through: :types

    SEVERITIES = [:high, :medium, :low, :informational]

    SEVERITIES.each do |severity|
        define_singleton_method severity do
            where( name: severity.to_s ).first
        end
    end

    def self.order_sql
        ret = 'CASE'
        SEVERITIES.each_with_index do |p, i|
            ret << " WHEN entry_type_severities.name = '#{p}' THEN #{i}"
        end
        ret << ' END'

        Arel.sql( ret )
    end

    def to_s
        name
    end

    def capitalize
        to_s.capitalize
    end

    def to_sym
        to_s.to_sym
    end

end
