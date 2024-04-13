# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

def scan_id
    Scan.count + 1
end

user = User.create(
    email:                 'test@stuff.com',
    password:              'testtest',
    password_confirmation: 'testtest'
)

engine_defaults  = Profile.flatten( SCNR::Engine::Options.to_rpc_data )

engine_defaults.merge!(
    name:        'Default',
    description: 'Sensible, default settings.',
    user:        user
)

Setting.create!( Setting.flatten( SCNR::Engine::Options.to_rpc_data ) )

all_checks_profile = Profile.create! engine_defaults.merge(
    name:        'Default',
    description: 'Sensible default settings.',
)
puts 'Default profile created: ' << all_checks_profile.name

devices = []

devices << firefox_ua = Device.create(
    name:          'Firefox',
    device_user_agent:    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0',
    device_width:  1200,
    device_height: 1600,
    device_touch:  false,
    device_pixel_ratio:   1.0
)

devices << ie_ua = Device.create(
    name:          'Edge',
    device_user_agent:    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.2210.121',
    device_width:  1200,
    device_height: 1600,
    device_touch:  false,
    device_pixel_ratio:   1.0
)

devices << ipad_ua = Device.create(
    name:          'iPad (portrait)',
    device_user_agent:    'Mozilla/5.0 (iPad; U; CPU OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B334b Safari/531.21.10',
    device_width:  768,
    device_height: 1024,
    device_touch:  true,
    device_pixel_ratio:   1.0
)

devices << iphone_ua = Device.create(
    name:          'iPhone (portrait)',
    device_user_agent:    'Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_4 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B350 Safari/8536.25',
    device_width:  320,
    device_height: 480,
    device_touch:  true,
    device_pixel_ratio:   1.0
)

puts 'Creating platforms'
SCNR::Engine::Platform::Manager::TYPES.each do |shortname, name|
    EntryPlatformType.create( shortname: shortname, name: name )
end

SCNR::Engine::Platform::Manager::PLATFORM_NAMES.each do |shortname, name|
    type = FrameworkHelper.platform_manager.find_type( shortname )
    EntryPlatformType.find_by_shortname( type ).platforms.create( shortname: shortname, name: name )
end

puts 'Creating sinks'
SCNR::Engine::Element::Capabilities::WithSinks::Sinks.enable_all
SCNR::Engine::Element::Capabilities::WithSinks::Sinks.tracers.values.each do |_, sinks|
    sinks.each do |sink|
        EntrySink.create( name: sink.to_s ) rescue PG::UniqueViolation
    end
end
