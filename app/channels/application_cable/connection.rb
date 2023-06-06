# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      user = env['warden'].user
      return reject_unauthorized_connection if user.blank?

      user
    end
  end
end
