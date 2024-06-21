class SiteProfilesController < ApplicationController
    include ControllerWithScannerOptions
    include SitesHelper

    before_action :set_site
    before_action :set_site_profile

    # PATCH/PUT /sites/1
    # PATCH/PUT /sites/1.json
    def update
        pp = parsed_params

        respond_to do |format|
            if @site_profile.update( pp )
                format.html do
                    redirect_to edit_site_url( @site ),
                                notice: 'Site settings were successfully updated.'
                end
                format.json { render :show, status: :ok, location: @site }
            else
                format.html { render '/sites/edit' }
                format.json { render json: @site.errors, status: :unprocessable_entity }
            end
        end
    end

    private

    def set_site
        @site = current_user.sites.find_by_id( params[:site_id] )

        raise ActionController::RoutingError.new( 'Site not found.' ) if !@site
    end

    def set_site_profile
        @site_profile = @site.profile
    end

    def permitted_attributes
        attributes = super.dup
        attributes << :max_parallel_scans
        attributes.delete :platforms
        attributes << { platforms: [] }
        attributes
    end

end
