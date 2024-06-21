source 'https://rubygems.org'

gem 'rails', '7.0.2.3'
gem 'sprockets'#, '3.7.2' # Fixes segfault on asset precompile.
gem 'sass-rails'#, '5.1.0' # Fixes segfault on asset precompile.
gem 'closure-compiler'
gem 'coffee-rails'
gem 'jquery-rails'
gem 'jbuilder'
gem 'bootstrap', '~> 5.2', '>= 5.2.3'
gem 'font-awesome-sass'
gem 'font-kit-rails'
gem 'devise'
# gem 'devise_security_extension', github: 'phatworx/devise_security_extension'
gem 'simple_form'

gem 'oj'
gem 'oj_mimic_json'

gem 'webpacker'
gem 'kramdown'
gem 'loofah'

gem 'd3-rails', '3.5.16'

gem 'ace-rails-ap'

gem 'coderay'
gem 'diffy'

gem 'pg'
gem 'sqlite3'

gem 'parse-cron'

gem 'dotiw'

gem 'vmstat'

gem 'sys-proctable'

# Audit trail
gem 'paper_trail'#, '~> 4.0.0'

gem 'turbo-rails'

group :doc do
    gem 'sdoc', '~> 0.4.0'
end

group :development do
    gem 'listen'
    gem 'spring'
    gem 'better_errors'
    gem 'binding_of_caller'
    # gem 'quiet_assets'
    gem 'rails_layout'
    gem 'bullet'
    # gem 'rails-footnotes'
end

group :test do
    gem 'shoulda'
    # gem 'capybara-webkit'
    # gem 'poltergeist'
    gem 'capybara'
    gem 'database_cleaner'
    gem 'faker'
    gem 'launchy'
    gem 'selenium-webdriver'
    gem 'factory_girl_rails'
    gem 'rspec-rails'
    gem 'action-cable-testing', '~> 0.6.1'
end

group :development, :test do
    gem 'puma'
    gem 'awesome_print'
    gem 'pry-byebug'
end

if File.exist? '../../qadron/cuboid'
    gem 'cuboid', path: '../../qadron/cuboid'
end

if File.exist? '../../ecsypno/license-client'
    gem 'ecsypno-license-client', path: '../../ecsypno/license-client'
else
    gem 'ecsypno-license-client'
end

if File.exist? '../../scnr/scnr'
    gem 'scnr', path: '../../scnr/scnr'
end

if File.exist? '../../scnr/engine'
    gem 'scnr-engine', path: '../../scnr/engine'
end

if File.exist? '../../scnr/application'
    gem 'scnr-application', path: '../../scnr/application'
end

if File.exist? '../../rkn/license-client'
    gem 'rkn-license-client', path: '../../rkn/license-client'
else
    gem 'rkn-license-client'
end

if File.exist? '../rkn'
    gem 'rkn', path: '../rkn'
else
    gem 'rkn'
end

if File.exist? '../application'
    gem 'rkn-application', path: '../application'
else
    gem 'rkn-application'
end
