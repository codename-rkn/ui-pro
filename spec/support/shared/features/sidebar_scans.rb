shared_examples_for 'Scans sidebar' do |options = {}|

    let(:scan) { FactoryGirl.create :scan, site: site, profile: profile }
    let(:revision) { FactoryGirl.create :revision, scan: scan }

    let(:profile) { FactoryGirl.create :profile }

    # Provided by parent.
    let(:site) { super() }
    let(:with_scans) { super() }

    def scans_sidebar_refresh
        visit current_url
    end

    before do
        revision
        with_scans.scans << scan
        scan.reload

        scans_sidebar_refresh
    end

    let(:sidebar) { find '#sidebar' }
    let(:scans) { find '#sidebar #sidebar-scans' }
    let(:scans) { sidebar.find '#sidebar-scans' }

    let(:info) { sidebar.find "#sidebar-scans-id-#{scan.id}-info" }

    let(:scan_info) { info.find '.scan-info' }
    it_behaves_like 'Scan info'

    let(:revision_info) { info.find '.revision-info' }
    it_behaves_like 'Revision info', extended: false, hide_scan_name: true

    scenario 'user sees name' do
        expect(scans).to have_content scan.name
    end

    scenario 'user sees amount of entries' do
        expect(scans.find("#sidebar-scans-id-#{scan.id} .badge")).to have_content scan.issues.size
    end

    scenario 'user sees scan link with filtering options' do
        expect(scans).to have_xpath "//a[starts-with(@href, '#{site_scan_path( site, scan )}/entries?filter') and not(@data-method)]"
    end

end
