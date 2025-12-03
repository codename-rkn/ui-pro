class ApplicationController < ActionController::Base
    include ApplicationHelper
    around_action :set_time_zone

    # Prevent CSRF attacks by raising an exception.
    # For APIs, you may want to use :null_session instead.
    protect_from_forgery with: :exception

    def authenticate_user!( *args )
        sign_in( User.first )
        super( *args )
    end

    private
    def set_time_zone
      if !Settings.timezone.blank?
        Time.use_zone( Settings.timezone ) { yield }
      else
        yield
      end
    end

end
