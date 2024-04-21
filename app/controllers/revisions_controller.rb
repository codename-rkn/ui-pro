class RevisionsController < ApplicationController
    include EntriesHelper
    include ScansHelper

    before_action :authenticate_user!

    before_action :set_scan
    before_action :set_revision

    include ScanResults

    # GET /revisions/1
    # GET /revisions/1.json
    def show
        redirect_to entries_site_scan_revision_path( @site, @scan, @revision, filter_params )
    end

    private

    def set_scan
        @scan = current_user.scans.joins(:revisions).find_by_id( params[:scan_id] )

        raise ActionController::RoutingError.new( 'Scan not found.' ) if !@scan

        prepare_scan_sidebar_data

        @site = @scan.site
    end

    def set_revision
        relation = @scan.revisions.includes(:performance_snapshot)

        if params[:action] == :health
            relation = relation.includes(:performance_snapshots)
        end

        @revision = relation.find( params[:id] )

        raise ActionController::RoutingError.new( 'Revision not found.' ) if !@revision
    end

    def scan_results_owner
        @revision
    end

    def scan_results_entries_owner
        # We can't filter entries at the revision level, that will remove a lot
        # of scan context from the rest of the interface, like from the revision
        # sidebar.
        @scan
    end

    def prepare_entry_data
        entries_summary_data(
            site:      @site,
            sitemap:   @revision.sitemap_entries,
            scans:     [@scan],
            revisions: @scan.revisions.order( id: :desc )
        )
    end

    def prepare_health_data
        return [] if !@revision.performance_snapshot.http_max_concurrency

        snapshots = []

        @revision.performance_snapshots.find_in_batches.map do |batch|
            batch.each do |snapshot|
                s = snapshot
                snapshot = s.attributes

                snapshot['duration'] =
                    SCNR::Engine::Utilities.seconds_to_hms( snapshot['runtime'] )

                snapshot['http_average_response_time'] =
                    snapshot['http_average_response_time'].round( 2 )

                snapshot['http_average_responses_per_second'] =
                    snapshot['http_average_responses_per_second'].to_i

                snapshot['download_kbps'] = s.download_kbps
                snapshot['upload_kbps']   = s.upload_kbps

                snapshots << snapshot
            end
        end

        snapshot = @revision.performance_snapshot.attributes
        snapshot['duration'] =
            SCNR::Engine::Utilities.seconds_to_hms( snapshot['runtime'] )
        snapshot['http_average_response_time'] =
            snapshot['http_average_response_time'].round( 2 )
        snapshot['http_average_responses_per_second'] =
            snapshot['http_average_responses_per_second'].to_i

        snapshots << snapshot
    end

end
