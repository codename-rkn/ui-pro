module SitesHelper
    include EntriesHelper

    def prepare_site_sidebar_data
        @site_sidebar = {
            scans: @scans,
            data:  {}
        }

        if filter_pages?
            @site_sidebar[:scans] = Set.new
        end

        process_entries_after_page_filter do |entry|
            if filter_pages?
                @site_sidebar[:scans] << entry.scan
            end

            @site_sidebar[:data][entry.scan_id] ||= {}
            @site_sidebar[:data][entry.scan_id][:max_severity] ||= entry.severity.to_s

            @site_sidebar[:data][entry.scan_id][:entry_count] ||= Set.new
            @site_sidebar[:data][entry.scan_id][:entry_count]  << entry.digest
        end

        process_entries_done do
            @site_sidebar[:data].each do |scan_id, data|
                @site_sidebar[:data][scan_id][:entry_count] =
                    data[:entry_count].size
            end

            @site_sidebar[:scans] =
                @site_sidebar[:scans].sort_by { |r| r.id }.reverse
        end
    end

    def site_profile_path( profile, *args )
        edit_site_path( profile.site_id, *args )
    end

end
