include Warden::Test::Helpers
Warden.test_mode!

# Feature: Site index page
#   As a user
#   I want to see a list of associated sites
feature 'Site index page' do

    let(:user) { FactoryGirl.create :user }
    let(:site) { FactoryGirl.create :site }
    let(:other_site) { FactoryGirl.create :site, host: 'gg.gg' }

    def refresh
        visit sites_path
    end

    after(:each) do
        Warden.test_reset!
    end

    before do
        other_site.host = 'test.gg'
        user.sites << site

        login_as( user, scope: :user )
        refresh
    end

    # Scenario: Site listed on index page
    #   Given I am signed in
    #   When I visit the site index page
    #   Then I see my sites
    scenario 'user sees URLs' do
        expect(page).to have_content site.url
        expect(page).to_not have_content other_site.url
    end

    scenario 'user sees show link' do
        expect(page).to have_xpath "//a[starts-with(@href, '#{issues_site_path( site )}?filter') and not(@data-method)]"
    end

    # Scenario: Sites which are verified are accompanied by delete links
    #   Given I am signed in
    #   When I visit the site index page
    #   Then I see my verified sites with delete links
    scenario 'user can delete' do
        expect(page).to have_xpath "//a[@href='#{site_path( site )}' and @data-method='delete']"
    end

    scenario 'icon links to site' do
        expect(find('a.site-favicon')[:href]).to eq site.url
    end

    feature 'when the site has a favicon' do
        before do
            IO.write( site.provisioned_favicon_path, '' )
            refresh
        end

        scenario 'user sees favicon' do
            expect(find('a.site-favicon img')[:src]).to eq "/site_favicons/#{site.favicon}"
        end
    end

    feature 'when the site has no favicon' do
        before do
            FileUtils.rm_f site.provisioned_favicon_path
            refresh
        end

        scenario 'user sees fa icon' do
            expect(find('a.site-favicon i')[:class]).to include 'fa fa-external-link'
        end
    end

    feature 'with scans' do
        before do
            scan
            refresh
        end

        let(:scan) { FactoryGirl.create :scan, site: site, profile: profile }
        let(:profile) { FactoryGirl.create :profile }

        feature 'without revisions' do
            scenario 'user sees undetermined last scan time' do
                expect(find('.last-scanned')).to have_content 'never'
            end

            scenario "user sees 'Undetermined' state label" do
                expect(find('span.label-severity-undetermined')).to have_content 'Undetermined'
            end
        end

        feature 'with revisions' do
            before do
                scan.revisions.create(
                    started_at: Time.now - 2000,
                    stopped_at: Time.now - 1000
                )

                refresh
            end

            scenario 'user sees time passed since last revision' do
                expect(page).to have_content '16 minutes ago'
                expect(page).to have_xpath "//a[@href='#{site_scan_revision_path( site, site.revisions.last.scan, site.revisions.last )}']"
            end

            feature 'with entries' do
                before do
                    10.times do
                        type.issues.create(
                            revision: site.revisions.first,
                            state:    'trusted'
                        )
                    end

                    refresh
                end

                let(:type) { FactoryGirl.create( :issue_type, severity: severity ) }

                {
                    high:   'Critical',
                    medium: 'Serious',
                    low:    'Fair'
                }.each do |s, state|
                    feature "with #{s} severity" do
                        let(:severity) { FactoryGirl.create( :issue_type_severity, name: s ) }

                        scenario "user sees '#{state}' state label" do
                            expect(find("span.label-severity-#{s}")).to have_content state
                        end

                        scenario 'user sees number of entries' do
                            expect(find('.state')).to have_content '10'
                        end
                    end
                end

                feature 'with informational severity' do
                    let(:severity) { FactoryGirl.create( :issue_type_severity, name: :informational ) }

                    scenario "user sees 'Good' state label" do
                        expect(find("span.label-severity-informational")).to have_content 'Good'
                    end
                end
            end
        end
    end

    feature 'without scans' do
        before do
            refresh
        end

        scenario 'user does not see the table' do
            expect(page).to_not have_content('#sites')
        end
    end

    feature 'new site form' do
        before do
            allow(SCNR::Engine::HTTP::Client).to receive(:get) do |url, options = {}|
                response.url = url if response
                response
            end

            select protocol, from: 'site[protocol]'
            fill_in 'site[host]', with: host
            fill_in 'site[port]', with: port
            click_button 'Add'
        end

        after do
            FileUtils.rm_f( new_site.provisioned_favicon_path ) if new_site
        end

        let(:response) do
            SCNR::Engine::HTTP::Response.new(
                url:     "#{url}/favicon.ico",
                code:    200,
                body:    'icon data',
                headers: {
                    'Content-Type' => 'image/x-icon'
                }
            )
        end

        let(:url) { "#{protocol}://#{host}:#{port}" }
        let(:protocol) { 'http' }
        let(:host) { 'example.com' }
        let(:port) { 8080 }

        let(:new_site) do
            Site.where( protocol: protocol, host: host, port: port ).first
        end

        scenario 'user can add new site' do
            expect(page).to have_content 'Site was successfully created.'

            expect(current_path).to eq edit_site_path(new_site)

            expect(new_site.protocol).to eq protocol
            expect(new_site.host).to eq host
            expect(new_site.port).to eq port
        end

        context 'validates connectivity' do
            let(:host_errors) do
                find '.site_host.has-error'
            end

            context 'when the Content-Type is for an image' do
                it 'stores the favicon' do
                    expect( IO.read( new_site.favicon_path ) ).to eq response.body
                end
            end

            context 'when the Content-Type is not for an image' do
                let(:response) do
                    super().tap do |response|
                        response.headers['content-type'] = 'text/html'
                    end
                end

                it 'does not store a favicon' do
                    expect(new_site).to_not have_favicon
                end
            end

            context 'when the request is invalid' do
                let(:response) do
                    nil
                end

                it 'shows error' do
                    expect(host_errors).to have_content 'could not get response'
                end

                it 'does not create the site' do
                    expect(new_site).to be_nil
                end
            end

            context 'when no connection could be made' do
                let(:response) do
                    SCNR::Engine::HTTP::Response.new(
                        url:            url,
                        code:           0,
                        return_message: 'Could not connect'
                    )
                end

                it 'shows error' do
                    expect(host_errors).to have_content response.return_message.downcase
                end

                it 'does not create the site' do
                    expect(new_site).to be_nil
                end
            end
        end

    end

    scenario 'protocol drop-down updates port', js: true do
        expect(find('#site_port').value).to eq '80'

        select 'https', from: 'site[protocol]'

        expect(find('#site_port').value).to eq '443'
    end
end
