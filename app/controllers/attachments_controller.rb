class AttachmentsController < ApplicationController
    before_action :authenticate_user!

    def show
        attachment = Attachment.find( params[:id] )
        send_data attachment.contents, filename: attachment.name, type: attachment.content_type
    end

    def destroy
        Attachment.find( params[:id] ).destroy

        respond_to do |format|
            format.html { redirect_back fallback_location: root_path, notice: 'Attachment was successfully deleted.' }
        end
    end

end
