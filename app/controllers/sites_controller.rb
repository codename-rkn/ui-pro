class SitesController < ApplicationController
    include SitesHelper

    before_action :authenticate_user!

    before_action :set_site, only: [:show, :edit, :destroy] +
                                       ScanResults::SCAN_RESULT_ACTIONS
    before_action :set_site_profile, only: [:show, :edit, :destroy]
    before_action :set_scans, only: ScanResults::SCAN_RESULT_ACTIONS

    include ScanResults

    # GET /sites
    # GET /sites.json
    def index
        set_sites
        @site = Site.new
    end

    def edit
    end

    # GET /sites/1
    # GET /sites/1.json
    def show
        if @site.scans.count == 0
            redirect_to new_site_scan_path( @site )
            return
        end

        redirect_to entries_site_path( @site, filter_params )
    end

    # POST /sites
    # POST /sites.json
    def create
        # SiteAddJob.perform_later( site_params, current_user )

        @site = Site.new( site_params )
        @site.user = current_user

        respond_to do |format|
            if validate_connectivity( @site ) && @site.save
                format.html { redirect_to edit_site_url(@site), notice: 'Site was successfully created.' }
                format.json { render :show, status: :created, location: @site }
            else
                set_sites

                format.html { render :index }
                format.json { render json: @site.errors, status: :unprocessable_entity }
            end
        end
    end

    # DELETE /sites/1
    # DELETE /sites/1.json
    def destroy
        fail 'Cannot delete site while scanning!' if @site.being_scanned?

        @site.destroying!
        SiteDeleteJob.perform_later( @site )

        respond_to do |format|
            format.html { redirect_to sites_url, status: 303, notice: 'Site is being deleted.' }
            format.json { head :no_content }
        end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_site
        @site = current_user.sites.find_by_id( params[:id] )

        raise ActionController::RoutingError.new( 'Site not found.' ) if !@site
    end

    def set_site_profile
        @site_profile = @site.profile
    end

    def set_sites
        @sites = current_user.sites.where( processing: nil ).order( id: :desc )
    end

    def set_scans
        @scans = @site.scans.includes(:schedule).includes(:device).
            includes(:site_role).includes(:profile).includes(:revisions)

        prepare_site_sidebar_data
    end

    def scan_results_owner
        @site
    end

    def prepare_entry_data
        entries_summary_data(
            site:      @site,
            sitemap:   @site.sitemap_entries,
            scans:     @scans.order( id: :desc ),
            revisions: @site.revisions.order( id: :desc )
        )
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def site_params
        params.require(:site).permit(*[ :protocol, :host, :port ])
    end

    def validate_connectivity( site )
        return true if site.protocol.blank? || site.host.blank? || site.port.blank?

        response = SCNR::Engine::HTTP::Client.get(
          "#{site.url}/favicon.ico",
          follow_location: true,
          mode:            :sync
        )

        if !response
            site.errors.add :host, "could not get response for: #{site.url}"
            return
        end

        if response.code == 0
            site.errors.add :host,
                            "#{response.return_message.to_s.downcase} for: #{site.url}"
            return
        end

        if response.headers['content-type'] &&
          response.headers['content-type'].start_with?( 'image' )
            IO.binwrite( site.provisioned_favicon_path, response.body )
        end

        true
    end

end
