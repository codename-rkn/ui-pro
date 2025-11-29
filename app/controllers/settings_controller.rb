class SettingsController < ApplicationController
    include ControllerWithScannerOptions

    before_action :authenticate_user!

    before_action :set_settings, only: [:index, :show, :edit, :update]

    def index
        render :edit
    end

    def show
        render :edit
    end

    def edit
    end

    def update
        respond_to do |format|
            if @settings.update( parsed_params )
                @@slots_total_auto = nil

                # The interface may need to perform certain operations too,
                # so apply the settings to the global libs for the interface
                # process.
                SCNR::Engine::Options.update @settings.to_scanner_options
                SCNR::Engine::HTTP::Client.reset

                format.html { render :edit }
                format.json { render :show, status: :ok, location: @settings }
            else
                format.html { render :edit }
                format.json { render json: @settings.errors, status: :unprocessable_entity }
            end
        end
    end

    private

    def set_settings
        @settings = Settings.record

        # TODO: Quite slow when a few scans are running.
        @slots_total_auto = (@@slots_total_auto ||= ScanScheduler.slots_total_auto)
    end

    def parsed_params
        parsed = super

        if parsed.delete( :max_parallel_scans_auto )
            parsed[:max_parallel_scans] = nil
        end

        parsed.permit( permitted_parsed_attributes )
    end

    def permitted_attributes
        attributes = super
        attributes << :timezone
        attributes << :max_parallel_scans
        attributes << :max_parallel_scans_auto
        attributes
    end

end
