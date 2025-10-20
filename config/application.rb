require File.expand_path('../boot', __FILE__)

require 'rails/all'

require 'rkn/application'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RKN
module UI
module Web
    VERSION = File.read( File.dirname( __FILE__ ) + '/../VERSION' ).strip

    class Application < Rails::Application
        config.load_defaults 6.0

        config.autoload_once_paths << Rails.root.join('lib')

        config.generators do |g|
            g.test_framework :rspec,
                             fixtures:         true,
                             view_specs:       false,
                             helper_specs:     false,
                             routing_specs:    false,
                             controller_specs: false,
                             request_specs:    false
            g.fixture_replacement :factory_girl, dir: "spec/factories"
        end

        # Settings in config/environments/* take precedence over those specified here.
        # Application configuration should go into files in config/initializers
        # -- all .rb files in that directory are automatically loaded.

        # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
        # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
        if File.exist? '/etc/timezone'
            config.time_zone = File.read('/etc/timezone').strip
        elsif (tz = ActiveSupport::TimeZone[Time.now.strftime('%z').gsub('0', '').to_i])
            config.time_zone = tz
        end

        # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
        # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
        # config.i18n.default_locale = :de
    end
end
end
end
