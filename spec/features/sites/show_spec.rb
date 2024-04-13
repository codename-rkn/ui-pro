# Feature: Site page
#   As a user
#   I want to visit a site
#   So I can see a site
feature 'Site page' do

    let(:user) { FactoryGirl.create :user }
    let(:other_user) { FactoryGirl.create(:user, email: 'other@example.com') }
    let(:site) { FactoryGirl.create :site, user: user }
    let(:profile) { FactoryGirl.create :profile }
    let(:other_site) { FactoryGirl.create :site, host: 'fff.com' }
    let(:scan) { FactoryGirl.create :scan, site: site, profile: profile }
    let(:revision) { FactoryGirl.create :revision, scan: scan }
    let(:other_scan) { FactoryGirl.create :scan, site: site, profile: profile, name: 'Blah' }

    before do
        revision
        user.sites << site

        login_as user, scope: :user
        visit site_path( site )
    end

    after(:each) do
        Warden.test_reset!
    end

    let(:site_info) { find '#site-info' }

    let(:site_sidebar_selected_button) do
        [:xpath, "a[starts-with(@href, '#{site_path( site )}/entries?filter') and not(@data-method)]"]
    end
    it_behaves_like 'Site sidebar'

    let(:with_scans) { site }
    it_behaves_like 'Scans sidebar'

    let(:with_sitemap_entries) { site }
    it_behaves_like 'Coverage'

    it_behaves_like 'Issue reviews'

    scenario 'has title' do
        expect(page).to have_title site.url
        expect(page).to have_title 'Sites'
    end

    scenario 'has breadcrumbs' do
        breadcrumbs = find('ul.bread')

        expect(breadcrumbs.find('li:nth-of-type(1) a').native['href']).to eq root_path

        expect(breadcrumbs.find('li:nth-of-type(2)')).to have_content 'Sites'
        expect(breadcrumbs.find('li:nth-of-type(2) a').native['href']).to eq sites_path

        expect(breadcrumbs.find('li:nth-of-type(3)')).to have_content site.url
        expect(breadcrumbs.find('li:nth-of-type(3) a').native['href']).to eq site_path( site )
    end

    scenario 'user sees Overview as heading' do
        expect(site_info.find('h1').text).to have_content 'Overview'
    end

    feature 'when the site has scans' do
        before do
            revision
            site.scans << scan
            site.save

            visit site_path( site )
        end

        let(:scan_info) { site_info.find '.scan-info' }
        it_behaves_like 'Scan info'

        let(:revision_info) { site_info.find '.revision-info' }
        it_behaves_like 'Revision info', extended: true
    end

    feature 'when the site has no scans' do
        before do
            user.sites << other_site

            login_as user, scope: :user
            visit site_path( other_site )
        end

        scenario 'user sees the new scan form' do
            expect(page).to have_xpath "//form[@id='new_scan']"
        end
    end

end
