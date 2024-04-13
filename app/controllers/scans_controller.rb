class ScansController < ApplicationController
    include ScansHelper

    STATES = [ :pause, :resume, :suspend, :restore, :abort ]

    before_action :authenticate_user!

    before_action :set_site
    before_action :set_scan, only: [:show, :repeat, :edit, :update, :destroy] +
                                       STATES + ScanResults::SCAN_RESULT_ACTIONS

    include ScanResults

    # GET /scans
    # GET /scans.json
    def index
        @active_scans = @scans.active
        @suspended_scans = @scans.suspended
        @finished_scans = @scans.finished
        @scheduled_scans = @scans.scheduled
    end

    # GET /scans/1
    # GET /scans/1.json
    def show
        redirect_to entries_site_scan_path( @site, @scan, filter_params )
    end

    # GET /scans/new
    def new
        fill_in_site_sidebar

        @scan = @site.scans.new
        @scan.build_schedule
    end

    # GET /scans/1/edit
    def edit
        fill_in_site_sidebar
    end

    # POST /scans
    # POST /scans.json
    def create
        @scan = @site.scans.new(scan_params)

        respond_to do |format|
            if @scan.save
                format.html { redirect_to [@site, @scan], notice: 'Scan was successfully created.' }
                format.json { render :show, status: :created, location: @scan }
            else
                fill_in_site_sidebar

                format.html { render :new }
                format.json { render json: @scan.errors, status: :unprocessable_entity }
            end
        end
    end

    def repeat
        @scan.schedule.start_at = Time.now
        @scan.status            = nil

        respond_to do |format|
            if @scan.save
                format.html { redirect_to [@site, @scan], notice: 'Scan was successfully scheduled.' }
                format.json { render :show, status: :created, location: @scan }
            else
                format.html { render :new }
                format.json { render json: @scan.errors, status: :unprocessable_entity }
            end
        end
    end

    # PATCH/PUT /scans/1
    # PATCH/PUT /scans/1.json
    def update
        respond_to do |format|
            if @scan.update( scan_params )
                format.html { redirect_to [@site, @scan], notice: 'Scan was successfully updated.' }
                format.json { render :show, status: :ok, location: @scan }
            else
                fill_in_site_sidebar

                format.html { render :edit }
                format.json { render json: @scan.errors, status: :unprocessable_entity }
            end
        end
    end

    STATES.each do |state|
        define_method state do
            ScanScheduler.instance.send( state, @scan.last_revision )
            redirect_back fallback_location: root_path, status: 303
        end
    end

    # DELETE /scans/1
    # DELETE /scans/1.json
    def destroy
        @scan.destroying!
        ScanDeleteJob.perform_later( @scan )

        respond_to do |format|
            format.html { redirect_to site_scans_url, status: 303, notice: 'The scan is being deleted.' }
            format.json { head :no_content }
        end
    end

    def preview_schedule
        if params[:id]
            @scan = @site.scans.find( params[:id] )
        end

        permitted_params = params.permit( permitted_schedule_attributes )
        schedule = Schedule.new( permitted_params )
        schedule.sanitize_start_at

        # If we have a scan pass it, we need to know how many revisions it has
        # in order to properly index the following occurrences.
        schedule.scan = @scan

        render partial: '/scans/schedule_preview',
               locals: {
                   scan:     @scan,
                   schedule: schedule
               }
    end

    private

    def set_site
        @site = current_user.sites.find_by_id( params[:site_id] )

        raise ActionController::RoutingError.new( 'Site not found.' ) if !@site

        @scans = @site.scans.includes(:schedule).includes(:device).
            includes(:site_role).includes(:profile).includes(:revisions)
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_scan
        @scan = @site.scans.includes(:schedule).includes(:device).
            includes(:site_role).includes(:profile).includes(:revisions).
            find( params[:id] )

        raise ActionController::RoutingError.new( 'Scan not found.' ) if !@scan

        prepare_scan_sidebar_data
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def scan_params
        permitted = params.require(:scan).permit( permitted_attributes )

        # TODO: Write specs for this.
        if permitted[:profile_id].to_i > 0
            # Fail if user tries to set a profile they do not own.
            current_user.profiles.find( params[:scan][:profile_id] )
        end

        permitted
    end

    def permitted_attributes
        [
            :name,
            :description,
            :path,
            :site_role_id,
            :profile_id,
            :device_id,
            :site_id,
            :id,
            :mark_missing_entries_fixed,
            {
                schedule_attributes: permitted_schedule_attributes
            }
        ]
    end

    def permitted_schedule_attributes
        [
            :month_frequency,
            :day_frequency,
            :start_at,
            :stop_after_hours,
            :stop_suspend,
            :frequency_base,
            :frequency_cron,
            :frequency_format
        ]
    end

    def fill_in_site_sidebar
        prepare_site_sidebar_data
        process_entries( @site.entries )
    end

    def scan_results_owner
        @scan
    end

    def prepare_entry_data
        entries_summary_data(
            site:      @site,
            sitemap:   @scan.sitemap_entries,
            scans:     [@scan],
            revisions: @scan.revisions.order( id: :desc ),
            entries:    scan_results_entries
        )
    end

end
