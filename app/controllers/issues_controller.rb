class IssuesController < ApplicationController
    before_action :authenticate_user!

    before_action :set_site
    before_action :set_scan
    before_action :set_revision
    before_action :set_issue

    # GET /issues/1
    # GET /issues/1.json
    def show
    end

    # PATCH/PUT /issues/1
    # PATCH/PUT /issues/1.json
    def update
        respond_to do |format|
            if @issue.update_state( issue_params[:state] )
                format.html { redirect_to @issue, notice: 'Issue was successfully updated.' }
                format.json { render :show, status: :ok, location: @issue }
                format.js { head :ok }
            else
                format.html { render :edit }
                format.json { render json: @issue.errors, status: :unprocessable_entity }
            end
        end
    end

    private

    def set_site
        @site = current_user.sites.find_by_id( params[:site_id] )

        raise ActionController::RoutingError.new( 'Site not found.' ) if !@site
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_scan
        @scan = @site.scans.includes(:site_role).find( params[:scan_id] )

        raise ActionController::RoutingError.new( 'Scan not found.' ) if !@scan
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_revision
        @revision = @scan.revisions.find( params[:revision_id] )

        raise ActionController::RoutingError.new( 'Revision not found.' ) if !@revision
    end

    def set_issue
        page_preloads = [
            {
                dom: [
                         {
                             execution_flow_sinks: {
                                 stackframes: :function
                             }
                         },
                         {
                             data_flow_sinks: [
                                 :function,
                                 stackframes: :function
                             ]
                         },
                         :transitions
                     ]
            },
            :response, :request, :sitemap_entry
        ]

        # TODO: Can fall into some sort of loop sometimes with a lot of
        # data_flow_sinks.
        @issue = @revision.issues.includes(:sitemap_entry).
            includes( reviewed_by_revision: :scan ).
            includes( input_vector: :sitemap_entry ).
            includes(:platform).includes(:remarks).
            includes( page: page_preloads ).
            includes( referring_page: page_preloads ).
            includes(:severity).includes(type: :references).
            includes(:siblings).includes( siblings: { revision: :scan } ).
            find( params[:id] )
    end

    def issue_params
        params.require(:issue).permit( permitted_attributes )
    end

    def permitted_attributes
        [ :state ]
    end
end
