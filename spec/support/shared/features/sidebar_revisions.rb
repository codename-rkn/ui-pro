shared_examples_for 'Revisions sidebar' do |options = {}|
    let(:site) { FactoryGirl.create :site }
    let(:scan) { FactoryGirl.create :scan, site: site, profile: profile }
    let(:revision) { FactoryGirl.create :revision, scan: scan }
    let(:other_revision) { FactoryGirl.create :revision, scan: scan }

    let(:profile) { FactoryGirl.create :profile }

    let(:sidebar) { find '#sidebar #sidebar-revisions' }

    def revisions_sidebar_refresh
        visit current_url
    end

    before do
        issue
        revisions_sidebar_refresh
    end

    let(:issue) do
        severity = FactoryGirl.create(:issue_type_severity, name: 'high' )

        type_name = "high-#{rand(25)}"
        type = FactoryGirl.create(
            :issue_type,
            severity: severity,
            name:     "Stuff #{type_name}",
            check_shortname: type_name
        )

        sitemap_entry = site.sitemap_entries.create(
            url:      "#{site.url}/#{severity}/",
            code:     200,
            revision: revision
        )

        set_sitemap_entries revision.issues.create(
            type:           type,
            page:           FactoryGirl.create(:issue_page),
            referring_page: FactoryGirl.create(:issue_page),
            input_vector:         FactoryGirl.create(:input_vector).
                                tap { |v| v.action = sitemap_entry.url },
            sitemap_entry:  sitemap_entry,
            digest:         rand(99999999999999),
            state:          'trusted'
        )
    end

    let(:info) { sidebar.find "#sidebar-revisions-id-#{revision.id}-info" }

    let(:revision_info) { info.find '.revision-info' }
    it_behaves_like 'Revision info', extended: false, hide_revision_name: true

    scenario 'user sees index' do
        expect(sidebar).to have_content "##{revision.index}"
    end

    scenario 'user sees amount of new pages' do
        revision.sitemap_entries.create(
            url:  revision.scan.url,
            code: 200
        )

        revisions_sidebar_refresh
        revision.reload

        sz = revision.sitemap_entries.size

        expect(sidebar).to have_content "#{sz} #{'page'.pluralize sz}"
    end

    scenario 'user sees amount of new entries' do
        expect(sidebar.find('span.badge')).to have_text revision.issues.size.to_s
    end

    feature 'when there are no reviewed entries' do
        scenario 'user does not see auto-review info' do
            expect(sidebar).to_not have_text "#{revision.reviewed_issues.size} reviewed"
        end
    end

    feature 'when there are reviewed entries' do
        before do
            revision.issues.first.update( reviewed_by_revision: revision )
            revisions_sidebar_refresh
        end

        scenario 'user sees amount of auto-reviewed entries' do
            expect(sidebar).to have_text "#{revision.reviewed_issues.size} reviewed"
        end
    end

    scenario 'user sees revision link with filtering options' do
        expect(sidebar).to have_xpath "//a[starts-with(@href, '#{site_scan_revision_path( site, scan, revision )}/entries?filter') and not(@data-method)]"
    end

end
