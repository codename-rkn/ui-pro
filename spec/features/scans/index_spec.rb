feature 'Scans index' do

    let(:user) { FactoryGirl.create :user }
    let(:other_user) { FactoryGirl.create(:user, email: 'other@example.com') }
    let(:site) { FactoryGirl.create :site, user: user }
    let(:profile) { FactoryGirl.create :profile }
    let(:other_site) { FactoryGirl.create :site, host: 'fff.com', user: user }
    let(:revision) { FactoryGirl.create :revision, scan: scan }
    let(:scan) { new_scan }
    let(:other_scan) { new_scan }

    def new_scan
        FactoryGirl.create :scan, site: site, profile: profile
    end

    before do
        revision
        user.sites << site

        login_as user, scope: :user
        visit site_scans_path( site )
    end

    after(:each) do
        Warden.test_reset!
    end

    def refresh
        visit current_url
    end

    let(:active) do
        new_scan.tap { |s| s.revisions.create( started_at: Time.now ).scanning! }
    end

    let(:suspended) do
        new_scan.tap { |s| s.revisions.create( started_at: Time.now ).suspended! }
    end
    let(:finished) do
        new_scan.tap do |s|
            s.revisions.create(
                started_at: Time.now,
                stopped_at: Time.now
            ).completed!
        end
    end

    before do
        other_scan.revisions.create
        site.scans << active
        site.scans << suspended
        site.scans << finished

        refresh
    end

    let(:site_sidebar_selected_button) { "a[@href='#{current_path}']" }
    it_behaves_like 'Site sidebar'

    scenario 'has title' do
        expect(page).to have_title 'Scans'
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

        expect(breadcrumbs.find('li:nth-of-type(4)')).to have_content 'Scans'
        expect(breadcrumbs.find('li:nth-of-type(4) a').native['href']).to eq site_scans_path( site )
    end

    feature 'that are active' do
        before do
            revision.scanning!
            refresh
        end

        let(:scan) { active }
        let(:scans) { find '#site-scans-active' }

        it_behaves_like 'Site scan tables row fields'

        scenario 'user sees scan status' do
            expect(scans).to have_content scan.status.capitalize
        end

        scenario 'user sees pause button' do
            expect(scans).to have_xpath "//a[@href='#{pause_site_scan_path( site, scan )}' and @data-method='patch']"
        end

        scenario 'user sees suspend button' do
            expect(scans).to have_xpath "//a[@href='#{suspend_site_scan_path( site, scan )}' and @data-method='patch']"
        end

        scenario 'user sees abort button' do
            expect(scans).to have_xpath "//a[@href='#{abort_site_scan_path( site, scan )}' and @data-method='patch']"
        end

        scenario 'user sees edit button' do
            expect(scans).to have_xpath "//a[@href='#{edit_site_scan_path( site, scan )}']"
        end

        feature 'when the scan is paused' do
            before do
                revision.paused!
                refresh
            end

            scenario 'user does not see pause button' do
                expect(scans).to_not have_xpath "//a[@href='#{pause_site_scan_path( site, scan )}']"
            end

            scenario 'user does not sees suspend button' do
                expect(scans).to_not have_xpath "//a[@href='#{suspend_site_scan_path( site, scan )}']"
            end

            scenario 'user sees resume button' do
                expect(scans).to have_xpath "//a[@href='#{resume_site_scan_path( site, scan )}' and @data-method='patch']"
            end
        end

        feature 'when there are no scans' do
            before do
                revision.completed!
                refresh
            end

            scenario 'shows message' do
                expect(scans.find(:css, 'p.alert.alert-info')).to have_content 'No active scans.'
            end
        end
    end

    feature 'that are suspended' do
        before do
            revision.suspended!
            refresh
        end

        let(:scan) { suspended }
        let(:scans) { find '#site-scans-suspended' }

        it_behaves_like 'Site scan tables row fields'

        scenario 'user sees scan name' do
            expect(scans).to have_content scan.name
        end

        scenario 'user sees revision' do
            expect(scans).to have_content scan.last_revision.index.ordinalize
        end

        scenario 'user sees scan profile' do
            expect(scans).to have_content scan.profile
        end

        scenario 'user sees amount of pages' do
            expect(scans).to have_content scan.sitemap_entries.size
        end

        scenario 'user sees amount of entries' do
            expect(scans).to have_content scan.issues.size
        end

        scenario 'user sees restore button' do
            expect(scans).to have_xpath "//a[@href='#{restore_site_scan_path( site, scan )}' and @data-method='patch']"
        end

        scenario 'user sees delete button' do
            expect(scans).to have_xpath "//a[@href='#{site_scan_path( site, suspended )}' and @data-method='delete']"
        end

        feature 'when there are no scans' do
            before do
                revision.completed!
                refresh
            end

            scenario 'shows message' do
                expect(scans.find(:css, 'p.alert.alert-info')).to have_content 'No suspended scans.'
            end
        end
    end

    feature 'that are finished' do
        before do
            revision.aborted!
            refresh
        end

        let(:scan) { finished }
        let(:scans) { find '#site-scans-finished' }

        it_behaves_like 'Site scan tables row fields'

        scenario 'user sees scan status' do
            expect(scans).to have_content revision.status.capitalize
        end

        scenario 'user sees repeat button' do
            expect(scans).to have_xpath "//a[@href='#{repeat_site_scan_path( site, finished )}' and @data-method='post']"
        end

        scenario 'user sees edit button' do
            expect(scans).to have_xpath "//a[@href='#{edit_site_scan_path( site, finished )}']"
        end

        scenario 'user sees delete button' do
            expect(scans).to have_xpath "//a[@href='#{site_scan_path( site, finished )}' and @data-method='delete']"
        end

        feature 'when there are no scans' do
            before do
                revision.scanning!
                refresh
            end

            scenario 'shows message' do
                expect(scans.find(:css, 'p.alert.alert-info')).to have_content 'No finished scans.'
            end
        end
    end
end
