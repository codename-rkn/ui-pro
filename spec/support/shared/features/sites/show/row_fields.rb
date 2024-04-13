shared_examples_for 'Site scan tables row fields' do
    include SiteRolesHelper

    scenario 'user sees scan name' do
        expect(scans).to have_content scan.name
    end

    scenario 'user sees revision' do
        expect(scans).to have_content scan.last_revision.index.ordinalize
    end

    scenario 'user sees scan profile' do
        expect(scans).to have_content scan.profile
        expect(scans).to have_xpath "//a[@href='#{profile_path( scan.profile )}']"
    end

    scenario 'user sees user agent' do
        expect(scans).to have_content scan.device
        expect(scans).to have_xpath "//a[@href='#{device_path( scan.device )}']"
    end

    scenario 'user sees site role' do
        expect(scans).to have_content scan.site_role
        expect(scans).to have_xpath "//a[@href='#{site_role_path( scan.site, scan.site_role )}']"
    end

    scenario 'user sees duration' do
        expect(scans).to have_content ApplicationHelper.seconds_to_hms( scan.last_revision.duration )
    end

    scenario 'user sees amount of pages for this revision' do
        expect(scans.find('.revision-sitemap-count')).to have_content revision.sitemap_entries.size
    end

    scenario 'user sees amount of pages for the scan' do
        expect(scans.find('.scan-sitemap-count')).to have_content scan.sitemap_entries.size
    end

    scenario 'user sees amount of entries for this revision' do
        expect(scans.find('.revision-issue-count')).to have_content revision.issues.size
    end

    scenario 'user sees amount of entries for this scan' do
        expect(scans.find('.scan-issue-count')).to have_content scan.issues.size
    end

    feature 'when the scan has no entries' do
        let(:max_severity) { scans.find('.scan-max-severity') }

        scenario 'user sees max severity of none' do
            expect(max_severity).to have_content 'None'
        end
    end

    feature 'when the revision has no entries' do
        let(:max_severity) { scans.find('.revision-max-severity') }

        scenario 'user sees max severity of none' do
            expect(scans).to have_content 'None'
        end
    end

end
