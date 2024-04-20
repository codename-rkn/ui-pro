module ScanResults
    extend ActiveSupport::Concern
    include ScanResultsHelper
    include RevisionsHelper

    included do
        before_action :set_counters, only: SCAN_RESULT_ACTIONS
    end

    REVERT_MODELS = [ :site_profile, :site_role ]

    DEFAULT_ACTION = :entries

    SCAN_RESULT_SITE_ACTIONS     = [ :entries, :coverage, :reviews, :events, :export, :summary ]

    SCAN_RESULT_SCAN_ACTIONS     =
        SCAN_RESULT_SITE_ACTIONS

    SCAN_RESULT_REVISION_ACTIONS =
        SCAN_RESULT_SITE_ACTIONS +
        SCAN_RESULT_SCAN_ACTIONS +
            [ :revert_configuration, :configuration, :health, :errors ]

    SCAN_RESULT_ACTIONS          = SCAN_RESULT_REVISION_ACTIONS

    SCAN_RESULT_SITE_ACTIONS_PER_CONTROLLER = {
        sites:     SCAN_RESULT_SITE_ACTIONS,
        scans:     SCAN_RESULT_SCAN_ACTIONS,
        revisions: SCAN_RESULT_REVISION_ACTIONS
    }

    def summary
        # @summary = prepare_live_stream_data
        @summary = entries_summary_data(
          site:      @site,
          sitemap:   (@revision || @scan || @site).sitemap_entries,
          scans:     @scan ? [@scan] : @site.scans,
          revisions: (@scan || @site).revisions.order( id: :desc ),
          entries:   scan_results_entries
        )
        process_and_show( :summary )
    end

    def entries
        @entries_summary = prepare_entry_data
        process_and_show( :entries )
    end

    def coverage
        @coverage = prepare_coverage_data
        process_and_show
    end

    def reviews
        @reviews = prepare_reviews_data

        process_and_show
    end

    def health
        @health = prepare_health_data
        process_and_show( :health )
    end

    def errors
        if @revision.error_messages.blank?
            redirect_to action: :show
            return
        end

        process_and_show
    end

    def events
        @events = prepare_events_data
        process_and_show
    end

    def configuration
        @configuration = prepare_configuration_data
        process_and_show
    end

    def export
        @report = scan_results_owner.report
        process_and_show
    end

    def revert_configuration
        revert_model = params.permit(:model)[:model].to_sym

        if !REVERT_MODELS.include?( revert_model )
            fail "Cannot revert #{revert_model}"
        end

        @configuration = prepare_configuration_data

        snapshot = @revision.send( revert_model )

        if revert_model == :site_role
            current  = @scan.site_role
        else
            current  = @site.profile
        end

        attributes = snapshot.attributes.dup
        %w(id site_id revision_id created_at updated_at).each do |attribute|
            attributes.delete attribute
        end

        if current.update( attributes )
            redirect_back fallback_location: configuration_revision_path( @revision ),
                          notice: 'Settings were successfully updated.'
        else
            redirect_back fallback_location: configuration_revision_path( @revision ),
                          notice: 'Settings could not be updated.'
        end
    end

    private

    def set_counters
        @coverage_count = scan_results_coverage.count(:url)
        @reviews_count  = filter_pages(
            scan_results_reviews_owner.reviewed_entries
        ).count
    end

    def scan_results_entries
        # Can't do filtering here, the rest of the interface relies of full
        # data in order to fill in context, like states etc.
        #
        # The filtering will take place in #process_entries.
        preload_entry_associations scan_results_entries_owner.entries
    end

    def scan_results_coverage
        scan_results_coverage_owner.sitemap_entries.coverage
    end

    def scan_results_events
        scan_results_events_owner.events
    end

    def scan_results_reviewed_entries
        # Reviewed entries don't really need further processing not are they
        # used to provide context for other areas, so we can do the filtering
        # here and get it over with.
        filter_pages(
            preload_entry_associations(
                scan_results_reviews_owner.reviewed_entries
            )
        )
    end

    # Starts the global {#process_entries entry processing} using
    # {#scan_results_entries}.
    def perform_entry_processing
        process_entries( preload_entry_associations( scan_results_entries ) )
    end

    def process_and_show(js_partial = :show)
        perform_entry_processing

        respond_to do |format|
            format.html {
                if params[:partial]
                    render partial: '/shared/scan_results',
                           format: :html
                else
                    render 'show'
                end
            }
            format.js { render js_partial }
        end
    end

    def prepare_coverage_data
        coverage_data( scan_results_coverage )
    end

    def prepare_reviews_data
        { entries: scan_results_reviewed_entries }
    end

    def prepare_configuration_data
        {
            snapshot: scan_results_owner.rpc_options,
            current:  @revision ? @revision.scan.rpc_options : nil
        }
    end

    def prepare_events_data
        scan_results_events
    end

    def prepare_entry_data
        fail 'Not implemented'
    end

    def prepare_health_data
        fail 'Not implemented'
    end

    def scan_results_owner
        fail 'Not implemented'
    end

    def scan_results_entries_owner
        scan_results_owner
    end

    def scan_results_coverage_owner
        scan_results_owner
    end

    def scan_results_reviews_owner
        scan_results_owner
    end

    def scan_results_events_owner
        scan_results_owner
    end

end
