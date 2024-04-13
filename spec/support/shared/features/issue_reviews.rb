shared_examples_for 'Issue reviews' do |options = {}|
    let(:profile) { FactoryGirl.create :profile }

    # Provided by parent.
    let(:revision) { super() }

    def issue_reviews_refresh
        visit current_url
        click_link 'Reviews'
    end

    after(:each) do
        Warden.test_reset!
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

    before do
        issue
        issue_reviews_refresh
    end

    feature 'Fixed' do
        let(:section) { find '#reviews-fixed' }
        let(:issue_row) { section.find "#reviews-fixed-issue-#{issue.digest}" }
        let(:issue)  do
            super().tap { |i| i.update_state( 'fixed', revision ) }
        end

        scenario 'lists fixed entries' do
            expect(section).to have_content issue.type.name
        end

        scenario 'links to the reviewer revision' do
            reviewer_link = issue_row.find( "#reviews-fixed-issue-#{issue.digest}-reviewer" ).
                find( :xpath, "a[starts-with(@href, '#{site_scan_revision_path( revision.site, revision.scan, revision )}')]" )

            expect(reviewer_link).to have_content "#{revision} of #{revision.scan} scan"
        end

        scenario 'links to sibling entries' do
            loggers = issue_row.find( "#reviews-fixed-issue-#{issue.digest}-loggers" )

            issue.siblings.each do |sibling|
                logger_link = loggers.find( :xpath, "//a[starts-with(@href, '#{site_scan_revision_issue_path( revision.site, revision.scan, revision, sibling )}')]" )
                expect(logger_link).to have_content "#{revision} of #{revision.scan} scan"
            end
        end
    end

    feature 'False positives' do
        let(:section) { find '#reviews-false_positives' }
        let(:issue_row) { section.find "#reviews-false_positives-issue-#{issue.digest}" }
        let(:issue)  do
            super().tap { |i| i.update_state( 'false_positive', revision ) }
        end

        scenario 'lists fixed entries' do
            expect(section).to have_content issue.type.name
        end

        scenario 'links to the reviewer revision' do
            reviewer_link = issue_row.find( "#reviews-false_positives-issue-#{issue.digest}-reviewer" ).
                find( :xpath, "a[starts-with(@href, '#{site_scan_revision_path( revision.site, revision.scan, revision )}')]" )

            expect(reviewer_link).to have_content "#{revision} of #{revision.scan} scan"
        end

        scenario 'links to sibling entries' do
            loggers = issue_row.find( "#reviews-false_positives-issue-#{issue.digest}-loggers" )

            issue.siblings.each do |sibling|
                logger_link = loggers.find( :xpath, "//a[starts-with(@href, '#{site_scan_revision_issue_path( revision.site, revision.scan, revision, sibling )}')]" )
                expect(logger_link).to have_content "#{revision} of #{revision.scan} scan"
            end
        end
    end

    feature 'Regressions' do
        let(:section) { find '#reviews-regressions' }
        let(:issue_row) { section.find "#reviews-regressions-issue-#{issue.digest}" }
        let(:issue)  do
            super().tap { |i| i.update_state( 'trusted', revision ) }
        end

        scenario 'lists fixed entries' do
            expect(section).to have_content issue.type.name
        end

        scenario 'links to the reviewer revision' do
            reviewer_link = issue_row.find( "#reviews-regressions-issue-#{issue.digest}-reviewer" ).
                find( :xpath, "a[starts-with(@href, '#{site_scan_revision_path( revision.site, revision.scan, revision )}')]" )

            expect(reviewer_link).to have_content "#{revision} of #{revision.scan} scan"
        end

        scenario 'links to sibling entries' do
            loggers = issue_row.find( "#reviews-regressions-issue-#{issue.digest}-loggers" )

            issue.siblings.each do |sibling|
                logger_link = loggers.find( :xpath, "ul//li//a[starts-with(@href, '#{site_scan_revision_issue_path( revision.site, revision.scan, revision, sibling )}')]" )
                expect(logger_link).to have_content "#{revision} of #{revision.scan} scan"
            end
        end
    end
end
