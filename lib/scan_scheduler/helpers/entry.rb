class ScanScheduler
module Helpers
module Entry

    def initialize
        super

        reset_entry_state
    end

    def create_entry( revision, native )
        log_debug_for revision, "Creating entry: #{native[:digest]}"
        update_updatable_data_for( revision, native )
        ::Entry.create_from_engine( native, revision: revision )
    end

    def import_entries_from_report( revision, report )
        scan_entries = Set.new( revision.scan.entries.where.not( revision: revision ).digests )

        report.each do |digest, entry|
            # Already logged by a previous revision, don't bother with it.
            if scan_entries.include?( digest )
                log_info_for revision, 'Entry already logged by previous' +
                    " revision: #{entry[:digest]}"
                next
            end

            create_entry( revision, entry )
        end

    end

    def reset_entry_state
        @updatable_entry_data_per_digest = {}
    end

    private

    def updatable_data_for( entry )
        @updatable_entry_data_per_digest[entry[:digest]] ||= ::Set.new
    end

    def update_updatable_data_for( revision, entry )
        updatable_data_for( entry ) <<
            hash_from_updatable_entry_data( revision, entry )
    end

    def update_issue?( revision, entry )
        !updatable_data_for( entry ).include?(
            hash_from_updatable_entry_data( revision, entry )
        )
    end

    def hash_from_updatable_entry_data( revision, entry )
        [
            revision.id,
        ].hash
    end

end
end
end
