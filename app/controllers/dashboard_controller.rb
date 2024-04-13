class DashboardController < ApplicationController
    before_action :authenticate_user!

    def index
        @entry_count_by_severity = {}
        IssueTypeSeverity.find_each do |severity|
            @entry_count_by_severity[severity.to_sym] = severity.entries.size
        end
    end

end
