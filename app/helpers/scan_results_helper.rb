module ScanResultsHelper

    FILTER_KEY    = :filter
    VALID_FILTERS = Set.new(%w(type pages states sinks platforms kinds))

    def process_entry_blocks
        @process_entry_blocks ||= []
    end
    def process_entry_blocks_call( entry )
        process_entry_blocks.each do |block|
            block.call entry
        end
    end
    def process_entry( &block )
        process_entry_blocks << block
    end

    def process_entries_after_revision_before_page_filter_blocks
        @process_entries_after_revision_before_page_filter_blocks ||= []
    end
    def process_entries_after_revision_before_page_filter_blocks_call( entry )
        process_entries_after_revision_before_page_filter_blocks.each do |block|
            block.call entry
        end
    end
    def process_entries_after_revision_before_page_filter( &block )
        process_entries_after_revision_before_page_filter_blocks << block
    end

    def process_entries_after_page_filter_blocks
        @process_entries_with_page_filter_blocks ||= []
    end
    def process_entries_after_page_filter_blocks_call( entry )
        process_entries_after_page_filter_blocks.each do |block|
            block.call entry
        end
    end
    def process_entries_after_page_filter( &block )
        process_entries_after_page_filter_blocks << block
    end

    def process_entries_selected_blocks
        @process_entries_selected_blocks ||= []
    end
    def process_entries_selected_blocks_call( entry )
        process_entries_selected_blocks.each do |block|
            block.call entry
        end
    end
    def process_entries_selected( &block )
        process_entries_selected_blocks << block
    end

    def process_entries_done_blocks
        @process_entries_done_blocks ||= []
    end
    def process_entries_done_blocks_call
        process_entries_done_blocks.each do |block|
            block.call
        end
    end
    def process_entries_done( &block )
        process_entries_done_blocks << block
    end

    def process_entries( entries, filters = {} )
        filter_by_revision = filters.include?(:by_revision) ?
            filters[:by_revision] : true

        entries_count = entries.count
        entries       = preload_entry_associations( entries )

        if filter_pages?
            @sitemap_entry = @site.sitemap_entries.where( digest: active_filters[:pages].first ).first
        end

        scoped_find_each( entries, size: entries_count ) do |entry|
            process_entry_blocks_call( entry )

            if !(filter_by_revision && @revision && @revision.id != entry.revision.id)
                process_entries_after_revision_before_page_filter_blocks_call( entry )
            end

            next if filter_pages? &&
                @sitemap_entry.digest != entry.sitemap_entry.digest

            process_entries_after_page_filter_blocks_call( entry )

            next if filter_by_revision && @revision &&
                @revision.id != entry.revision.id

            next if !matches_filters?( entry )

            process_entries_selected_blocks_call( entry )
        end

        process_entries_done_blocks_call
    end

    def matches_filters?( entry )
        if filter_states?
            return false if !matches_states_filters?( entry )
        end

        if filter_kinds?
            return false if !matches_kinds_filters?( entry )
        end

        if filter_platforms?
            return false if !matches_kinds_filters?( entry )
        end

        if filter_sinks?
            return false if !matches_sinks_filters?( entry )
        end

        true
    end

    def matches_states_filters?( entry )
        ([entry.state] & active_filters[:states]).any?
    end

    def matches_kinds_filters?( entry )
        active_filters[:kinds].include? entry.input_vector.kind.to_s
    end

    def matches_platforms_filters?( entry )
        (active_filters[:platforms] & entry.platforms.map(&:shortname)).any?
    end

    def matches_sinks_filters?( entry )
        (active_filters[:sinks] & entry.sinks.map(&:name)).any?
    end

    def apply_filters( entries )
        if filter_states?
            entries = filter_states( entries )
        end

        if filter_kinds?
            entries = filter_kinds( entries )
        end

        if filter_platforms?
            entries = filter_platforms( entries )
        end

        if filter_sinks?
            entries = filter_sinks( entries )
        end

        entries
    end

    def entries_summary_data( data )
        store = {}

        if !data[:scans].is_a?( Array )
            data[:scans] = data[:scans].includes(:revisions).
                includes(:schedule).includes(:profile)
        end

        entries = data[:entries]

        sitemap_with_entries  = {}
        chart_data           = {}
        pre_page_filter_data = {}
        revision_data        = {}
        unique_entries_count  = Set.new
        page_filtered_entries = []
        pre_page_filter_data[:count] = 0

        process_entry do |entry|
            pre_page_filter_data[:count] += 1
        end

        process_entries_after_revision_before_page_filter do |entry|
            update_chart_data( chart_data, entry )
            update_sitemap_data( sitemap_with_entries, entry )
        end

        # If we're filtering by page, also filter out scans and revisions which
        # haven't logged entries for it.
        if filter_pages?
            data[:scans]     = Set.new
            data[:revisions] = Set.new
        end

        counted_attributes = {
          states: {},
          sinks: {},
          platforms: {},
          input_vectors: {},
        }

        process_entries_after_page_filter do |entry|
            if filter_pages?
                data[:scans]     << entry.scan
                data[:revisions] << entry.revision
            end

            unique_entries_count << entry.digest

            revision_data[entry.revision_id] ||= {}
            revision_data[entry.revision_id][:entry_count] ||= 0
            revision_data[entry.revision_id][:entry_count]  += 1

            counted_attributes[:states][entry.state] ||= 0
            counted_attributes[:states][entry.state] += 1

            entry.sinks.each do |sink|
                counted_attributes[:sinks][sink.name] ||= 0
                counted_attributes[:sinks][sink.name] += 1
            end

            entry.platforms.each do |platform|
                counted_attributes[:platforms][platform.shortname] ||= 0
                counted_attributes[:platforms][platform.shortname] += 1
            end

            counted_attributes[:input_vectors][entry.input_vector.kind.to_s] ||= 0
            counted_attributes[:input_vectors][entry.input_vector.kind.to_s] += 1
        end

        process_entries_selected do |entry|
            if pre_page_filter_data[:count] > ApplicationHelper::SCOPED_FIND_EACH_BATCH_SIZE
                next
            end

            page_filtered_entries << entry
        end

        process_entries_done do
            # If the total entries are above the batch size, apply any page filtering
            # via a scope.
            if pre_page_filter_data[:count] > ApplicationHelper::SCOPED_FIND_EACH_BATCH_SIZE
                page_filtered_entries = filter_pages( entries )

                if @revision
                    page_filtered_entries = page_filtered_entries.where( revision: @revision )
                end
            end

            sitemap_data = {
                entry_count: 0
            }

            if sitemap_with_entries.any?
                sitemap_data[:entry_count]  =
                    sitemap_with_entries.values.map { |v| v[:entry_count] }.inject(:+)
            end

            if data[:revisions].is_a? Set
                data[:revisions] = data[:revisions].sort_by { |r| r.id }.reverse
            end

            if data[:scans].is_a? Set
                data[:scans] = data[:scans].sort_by { |r| r.id }.reverse
            end

            missing_entries = nil
            if @revision && @scan.completed?
                missing_entries = filter_pages( @revision.missing_entries )
            end

            ap '-' * 88
            ap page_filtered_entries.size

            store.merge!(
                site:                data[:site],
                scans:               data[:scans],
                revisions:           data[:revisions],
                sitemap:             data[:sitemap],
                sitemap_with_entries: sitemap_with_entries,
                states:              counted_attributes[:states],
                platforms:           counted_attributes[:platforms],
                sinks:               counted_attributes[:sinks],
                input_vector_kinds:  counted_attributes[:input_vectors],
                sitemap_data:        sitemap_data,
                entries:             page_filtered_entries,
                missing_entries:      missing_entries,
                chart_data:          chart_data,
                revision_data:       revision_data,
                unique_entries_count: unique_entries_count.size
            )
        end

        store
    end

    def coverage_data( coverage )
        current_digests             = Set.new
        up_to_now_exclusive_digests = Set.new
        up_to_now_inclusive         = {}

        if @revision && @revision.index > 1
            current_digests.merge coverage.reorder('').pluck(:digest)

            SitemapEntry.coverage.where(
                revision: @scan.revisions.reorder( id: :asc )[0..(@revision.index-1)]
            ).each do |entry|
                up_to_now_inclusive[entry.digest] = entry

                next if entry.revision_id == @revision.id
                up_to_now_exclusive_digests << entry.digest
            end
        end

        {
            coverage:                    coverage,
            current_digests:             current_digests,
            up_to_now_inclusive:         up_to_now_inclusive,
            up_to_now_exclusive_digests: up_to_now_exclusive_digests,
        }
    end

    def update_sitemap_data( data, entry )
        data[entry.input_vector.action] ||= {
            internal:     sitemap_entry_url( entry.sitemap_entry.digest ),
            digest:       entry.sitemap_entry.digest,
            entry_count:  0,
            seen:         Set.new
        }

        return if data[entry.input_vector.action][:seen].include? entry.digest
        data[entry.input_vector.action][:seen] << entry.digest

        data[entry.input_vector.action][:entry_count] += 1
    end

    def update_chart_data( data, entry )
        if data.empty?
            data.merge!(
                entry_names:   {},
                seen:          Set.new,
                total_entries: 0
            )
        end

        if filter_pages? && !page_id_in_filter?( entry.sitemap_entry.digest )
            return
        end

        return if data[:seen].include?( entry.digest )
        data[:seen] << entry.digest

        data[:total_entries] += 1

        name = entry.input_vector.kind

        data[:entry_names][name] ||= 0
        data[:entry_names][name]  += 1
    end

    def link_to_with_filters( *args, &block )
        name, resource, options = *args

        if name.is_a? ActiveRecord::Base
            options = resource
            resource = name
            name     = nil
        end

        options ||= {}

        route = {
            controller: resource.class.name.tableize,
            params:     filter_params
        }

        if ScanResults::SCAN_RESULT_ACTIONS.include?( params[:action].try(:to_sym) )
             route[:action] = params.permit(:action)[:action]
        else
            route[:action] = options[:action] || 'entries'
        end

        ScanResults::SCAN_RESULT_SITE_ACTIONS_PER_CONTROLLER.each do |controller, actions|
            # If the controller doesn't support the current action revert to
            # the default.
            if route[:controller].to_sym == controller &&
                !actions.include?( route[:action].to_sym )
                route[:action] = ScanResults::DEFAULT_ACTION
            end

            parent = controller.to_s.singularize
            if resource.respond_to?( parent )
                route["#{parent}_id"] = resource.send( "#{parent}_id" )
            end
        end

        route['id'] = resource.id

        link_to *[name, route, options].compact, &block
    end

    def filter_params
        { FILTER_KEY => active_filters }
    end

    def filter_params_without_page
        { FILTER_KEY => active_filters.merge( pages: [] ) }
    end

    def filter_states( entries )
        return entries if active_filters[:states].empty?

        if active_filters[:type] == 'exclude'
            entries.where.not( state: active_filters[:states] )
        else
            entries.where( state: active_filters[:states] )
        end
    end

    def filter_kinds( entries )
        return entries if active_filters[:kinds].empty?

        if active_filters[:type] == 'exclude'
            entries.where.not( input_vectors: { kind: active_filters[:kinds] } )
        else
            entries.where( input_vectors: { kind: active_filters[:kinds] } )
        end
    end

    def filter_sinks( entries )
        return entries if active_filters[:sinks].empty?

        if active_filters[:type] == 'exclude'
            entries.where.not( sinks: { name: active_filters[:sinks] } )
        else
            entries.where( sinks: { name: active_filters[:sinks] } )
        end
    end

    def filter_platforms( entries )
        return entries if active_filters[:platforms].empty?

        if active_filters[:type] == 'exclude'
            entries.where.not( platforms: { name: active_filters[:platforms] } )
        else
            entries.where( platforms: { name: active_filters[:platforms] } )
        end
    end

    def filter_pages?
        active_filters[:pages].any?
    end

    def filter_states?
        active_filters[:states].any?
    end

    def filter_kinds?
        active_filters[:kinds].any?
    end

    def filter_platforms?
        active_filters[:platforms].any?
    end

    def filter_sinks?
        active_filters[:sinks].any?
    end

    def page_id_in_filter?( page_id )
        active_filters[:pages].include? page_id.to_s
    end

    def filter_pages( entries )
        return entries if !filter_pages?

        entries.includes( :sitemap_entry ).
            where( 'sitemap_entries.digest IN (?)', active_filters[:pages] )
    end

    def preload_entry_associations( entries )
        entries.
            includes( :scan ).
            includes( :type ).
            includes( :input_vector ).
            includes( :sitemap_entry ).
            includes( :sinks ).
            includes( :platforms ).
            includes( revision: { scan: [:profile] } ).
            includes( :reviewed_by_revision ).
            includes( page: :sitemap_entry ).
            includes( siblings: :revision ).
            includes( siblings: :scan )
    end

    def active_filters
        return @active_filters if @active_filters

        if params[FILTER_KEY]
            @active_filters =
                params.extract!(FILTER_KEY)[FILTER_KEY].to_unsafe_h.
                    select { |f| VALID_FILTERS.include? f }
        else
            @active_filters = {}
        end

        @active_filters[:type]  ||= 'include'
        @active_filters[:pages] ||= []
        @active_filters[:sinks] ||= []
        @active_filters[:platforms] ||= []
        @active_filters[:kinds] ||= []

        if @active_filters[:type] == 'include'
            @active_filters[:states] ||= %w(pending)
        else
            @active_filters[:states] ||= []
        end

        @active_filters
    end

end
