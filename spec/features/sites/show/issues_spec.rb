feature 'Site' do
    include SiteRolesHelper

    let(:user) { FactoryGirl.create :user }
    let(:other_user) { FactoryGirl.create(:user, email: 'other@example.com') }
    let(:site) { FactoryGirl.create :site }
    let(:profile) { FactoryGirl.create :profile }
    let(:other_site) { FactoryGirl.create :site, host: 'fff.com' }
    let(:scan) { FactoryGirl.create :scan, site: site, profile: profile }
    let(:revision) { FactoryGirl.create :revision, scan: scan }
    let(:other_revision) { FactoryGirl.create :revision, scan: other_scan }
    let(:other_scan) { FactoryGirl.create :scan, site: site, profile: profile, name: 'Blah' }

    before do
        user.sites << site
        revision

        login_as user, scope: :user
        visit site_path( site )
    end

    after(:each) do
        Warden.test_reset!
    end

    let(:site_info) { find '#site-info' }

    feature 'without revisions' do
        before do
            FactoryGirl.create( :scan, site: other_site, profile: profile )

            user.sites << other_site

            visit site_path( other_site )
        end

        scenario 'user sees notice' do
            expect(page).to have_text 'No scan has started yet'
        end
    end

    feature 'with scans' do
        before do
            revision
            site.scans << scan
            scan.reload

            visit site_path( site )
        end

        feature 'with entries' do
            let(:issues) { find '#summary-entries' }

            before do
                100.times do |i|
                    site.sitemap_entries.create(
                        url:      "#{site.url}/#{i}",
                        code:     200,
                        revision: site.revisions.sample
                    )
                end

                @severities = {}
                @types      = {}
                revision    = nil
                25.times do |i|
                    if (i % 5) == 0
                        scan     = FactoryGirl.create( :scan, site: site, profile: profile )
                        revision = FactoryGirl.create( :revision, scan: scan )
                    end

                    IssueTypeSeverity::SEVERITIES.each do |severity|
                        @severities[severity] ||=
                            FactoryGirl.create(:issue_type_severity,
                                               name: severity )

                        type_name = "#{severity}-#{rand(25)}"
                        type = @types[type_name] ||= FactoryGirl.create(
                            :issue_type,
                            severity: @severities[severity],
                            name:     "Stuff #{type_name}",
                            check_shortname: type_name
                        )

                        sitemap_entry = site.sitemap_entries.create(
                            url:      "#{site.url}/#{severity}/#{i}",
                            code:     i,
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
                end

                visit "#{site_path( site )}?filter[states][]=trusted&filter[states][]=untrusted&filter[states][]=false_positive&filter[states][]=fixed&filter[severities][]=high&filter[severities][]=medium&filter[severities][]=low&filter[severities][]=informational&filter[type]=include"
            end

            let(:types) { @types.values }
            let(:severities) { @severities.values }

            # feature 'when filtering' do
            #     let(:sitemap_entry) { site.entries.first.input_vector.sitemap_entry}
            #     let(:path) { URI(sitemap_entry.url).path }
            #
            #     states = ['Trusted', 'untrusted', 'false positive', 'fixed']
            #
            #     feature 'page' do
            #         feature 'with entries' do
            #             before do
            #                 visit "#{site_path( site )}?filter[pages][]=#{sitemap_entry.digest}&filter[states][]=trusted&filter[states][]=untrusted&filter[states][]=false_positive&filter[states][]=fixed&filter[severities][]=high&filter[severities][]=medium&filter[severities][]=low&filter[severities][]=informational&filter[type]=include"
            #             end
            #
            #             scenario 'only shows entries for that page' do
            #                 all_digests = site.entries.pluck(:digest)
            #                 sitemap_digests = sitemap_entry.entries.pluck(:digest)
            #
            #                 sitemap_digests.each do |digest|
            #                     expect(entries).to have_css "#summary-issue-#{digest}"
            #                 end
            #
            #                 expect(all_digests - sitemap_digests).to be_any
            #
            #                 (all_digests - sitemap_digests).each do |digest|
            #                     expect(entries).to_not have_css "#summary-issue-#{digest}"
            #                 end
            #             end
            #
            #             feature 'sidebar' do
            #                 let(:sidebar) { find '#sidebar-scans' }
            #
            #                 scenario 'only shows scans that have logged entries for that page' do
            #                     all_scans  = site.scans.pluck(:name)
            #                     page_scans = sitemap_entry.entries.map { |i| i.scan }.map(&:name)
            #
            #                     page_scans.each do |name|
            #                         expect(sidebar).to have_content name
            #                     end
            #
            #                     expect(all_scans - page_scans).to be_any
            #
            #                     (all_scans - page_scans).each do |name|
            #                         expect(sidebar).to_not have_content name
            #                     end
            #                 end
            #             end
            #
            #             scenario 'user sees the page URL in the heading' do
            #                 expect(site_info.find('h1')).to have_content "showing #{path}"
            #             end
            #         end
            #
            #         feature 'without entries' do
            #             before do
            #                 visit "#{site_path( site )}?filter[pages][]=#{sitemap_entry.digest}&filter[states][]=trusted&filter[states][]=untrusted&filter[states][]=false_positive&filter[states][]=fixed&filter[severities][]=high&filter[severities][]=medium&filter[severities][]=low&filter[severities][]=informational&filter[type]=exclude"
            #             end
            #
            #             let(:message) do
            #                 find( '#entries-summary div.well' )
            #             end
            #
            #             scenario 'shows message' do
            #                 expect(message).to have_content 'No entries for'
            #             end
            #
            #             scenario 'message includes internal page URL' do
            #                 expect(message).to have_xpath "//a[@href='#{sitemap_entry.url}']"
            #             end
            #
            #             scenario 'message includes external page URL' do
            #                 expect(message).to have_xpath "//a[@href='#{sitemap_entry.url}']"
            #             end
            #
            #             feature 'for any page' do
            #                 scenario 'message includes clearing filters filter' do
            #                     within message do
            #                         click_link 'clear all filters'
            #
            #                         url = issues_site_url(revision.scan.site)
            #                         expect(current_url).to eq url
            #                     end
            #                 end
            #             end
            #
            #             feature 'but has entries for other pages' do
            #                 before do
            #                     sitemap_entry.entries.reorder('').delete_all
            #                     visit "#{site_path( site )}?filter[pages][]=#{sitemap_entry.digest}"
            #                 end
            #
            #                 scenario 'message includes clearing filters filter' do
            #                     within message do
            #                         click_link 'all pages'
            #
            #                         expect(current_url).to_not include 'filtet[states][pages]'
            #                     end
            #                 end
            #             end
            #         end
            #     end
            #
            #     context 'by state', js: true do
            #         states.each do |type|
            #             state = type.sub( ' ', '_' ).downcase
            #
            #             feature type do
            #                 before do
            #                     states.each do |t|
            #                         normalized_t = t.sub( ' ', '_' ).downcase
            #                         page.execute_script( "document.getElementById( 'issue-state-#{normalized_t}' ).checked = false;" )
            #
            #                         set_sitemap_entries revision.entries.create(
            #                             type:           IssueType.first,
            #                             page:           FactoryGirl.create(:issue_page),
            #                             referring_page: FactoryGirl.create(:issue_page),
            #                             input_vector:         FactoryGirl.create(:input_vector).
            #                                                 tap { |v| v.action = sitemap_entry.url },
            #                             sitemap_entry:  sitemap_entry,
            #                             digest:         rand(99999999999999),
            #                             state:          normalized_t
            #                         )
            #                     end
            #
            #                     expect(revision.reload.entries).to be_any
            #                     expect(state_issues).to be_any
            #                     expect(other_issues).to be_any
            #
            #                     find( 'label', text: /#{type}/ ).click
            #
            #                     IssueTypeSeverity::SEVERITIES.each do |severity|
            #                         page.execute_script( "document.getElementById( 'issue-severity-#{severity}' ).checked = false;" )
            #                     end
            #                 end
            #
            #                 let(:other_issues) { revision.entries.where.not state: state }
            #                 let(:state_issues) { revision.entries.where state: state }
            #
            #                 feature 'Show' do
            #                     before do
            #                         click_button 'Show'
            #                     end
            #
            #                     it 'does not show other entries' do
            #                         other_issues.each do |issue|
            #                             expect(entries).to_not have_css "#summary-issue-#{issue.digest}"
            #                         end
            #                     end
            #
            #                     it "shows #{type} entries" do
            #                         state_issues.each do |issue|
            #                             expect(entries).to have_css "#summary-issue-#{issue.digest}"
            #                         end
            #                     end
            #                 end
            #
            #                 feature 'Hide' do
            #                     before do
            #                         click_button 'Hide'
            #                     end
            #
            #                     it 'shows other entries' do
            #                         other_issues.each do |issue|
            #                             expect(entries).to have_css "#summary-issue-#{issue.digest}"
            #                         end
            #                     end
            #
            #                     it "does not show #{type} entries" do
            #                         state_issues.each do |issue|
            #                             expect(entries).to_not have_css "#summary-issue-#{issue.digest}"
            #                         end
            #                     end
            #                 end
            #             end
            #         end
            #     end
            #
            #     context 'by severity', js: true do
            #         IssueTypeSeverity::SEVERITIES.each do |severity|
            #             feature severity.to_s do
            #                 before do
            #                     IssueTypeSeverity::SEVERITIES.each do |s|
            #                         page.execute_script( "document.getElementById( 'issue-severity-#{s}' ).checked = false;" )
            #
            #                         @severities[s] ||=
            #                             FactoryGirl.create(:issue_type_severity,
            #                                                name: s )
            #
            #                         type_name = "#{s}-#{rand(999999999999)}"
            #                         @types[s] ||= FactoryGirl.create(
            #                             :issue_type,
            #                             severity: @severities[s],
            #                             name:     "Stuff #{type_name}",
            #                             check_shortname: type_name
            #                         )
            #
            #                         set_sitemap_entries revision.entries.create(
            #                             type:           @types[s],
            #                             page:           FactoryGirl.create(:issue_page),
            #                             referring_page: FactoryGirl.create(:issue_page),
            #                             input_vector:         FactoryGirl.create(:input_vector).
            #                                                 tap { |v| v.action = sitemap_entry.url },
            #                             sitemap_entry:  sitemap_entry,
            #                             digest:         rand(99999999999999),
            #                             state:          'trusted'
            #                         )
            #                     end
            #
            #                     expect(revision.reload.entries).to be_any
            #                     expect(severity_issues).to be_any
            #                     expect(other_issues).to be_any
            #
            #                     page.execute_script( "document.getElementById( 'issue-severity-#{severity}' ).checked = true;" )
            #
            #                     states.each do |state|
            #                         s = state.sub( ' ', '_' ).downcase
            #                         page.execute_script( "document.getElementById( 'issue-state-#{s}' ).checked = false;" )
            #                     end
            #                 end
            #
            #                 let(:other_issues) do
            #                     revision.entries.joins(:severity).where.
            #                         not( 'issue_type_severities.name = ?', severity )
            #                 end
            #                 let(:severity_issues) { revision.entries.send( "#{severity}_severity" ) }
            #
            #                 feature 'Show' do
            #                     before do
            #                         click_button 'Show'
            #                     end
            #
            #                     it 'does not show other entries' do
            #                         other_issues.each do |issue|
            #                             expect(entries).to_not have_css "#summary-issue-#{issue.digest}"
            #                         end
            #                     end
            #
            #                     it "shows #{severity} severity entries" do
            #                         severity_issues.each do |issue|
            #                             expect(entries).to have_css "#summary-issue-#{issue.digest}"
            #                         end
            #                     end
            #                 end
            #
            #                 feature 'Hide' do
            #                     before do
            #                         click_button 'Hide'
            #                     end
            #
            #                     it "does not show #{severity} severity entries" do
            #                         severity_issues.each do |issue|
            #                             expect(entries).to_not have_css "#summary-issue-#{issue.digest}"
            #                         end
            #                     end
            #
            #                     it 'shows all other entries' do
            #                         other_issues.each do |issue|
            #                             expect(entries).to have_css "#summary-issue-#{issue.digest}"
            #                         end
            #                     end
            #                 end
            #             end
            #         end
            #     end
            # end
            #
            # feature 'grouped by severity' do
            #     scenario 'user sees color-coded containers' do
            #         IssueTypeSeverity::SEVERITIES.each do |severity|
            #             expect(entries.find("div#summary-issue-severity-#{severity}")[:class]).to include "bg-severity-#{severity}"
            #         end
            #     end
            #
            #     feature 'and by type' do
            #         scenario 'user sees issue type headings' do
            #             types.each do |type|
            #                 expect(entries.find("#summary-issue-check-#{type.check_shortname} h4")).to have_content type.name
            #             end
            #         end
            #
            #         scenario 'user sees amount of entries in the heading' do
            #             types.each do |type|
            #                 expect(entries.find("#summary-issue-check-#{type.check_shortname} h4 span.badge-severity-#{type.severity.name}")).to have_content type.entries.size
            #             end
            #         end
            #
            #         feature 'for each issue' do
            #             feature 'scan info' do
            #                 scenario 'user sees scan name' do
            #                     site.entries.each do |issue|
            #                         expect(entries.find("#summary-issue-#{issue.digest}")).to have_content issue.revision.scan.name
            #                     end
            #                 end
            #
            #                 scenario 'user sees revision link with filtering options' do
            #                     site.entries.each do |issue|
            #                         path = site_scan_revision_path(issue.revision.scan.site, issue.revision.scan, issue.revision)
            #                         expect(entries.find("#summary-issue-#{issue.digest}")).to have_xpath "//a[starts-with(@href, '#{path}?filter')]"
            #                     end
            #                 end
            #
            #                 scenario 'user sees revision index' do
            #                     site.entries.each do |issue|
            #                         expect(entries.find("#summary-issue-#{issue.digest}")).to have_content issue.revision.index
            #                     end
            #                 end
            #
            #                 scenario 'user sees revision link with filtering options' do
            #                     site.entries.each do |issue|
            #                         expect(entries.find("#summary-issue-#{issue.digest}")).to have_xpath "//a[starts-with(@href, '#{site_scan_revision_path(issue.revision.scan.site, issue.revision.scan, issue.revision)}?filter')]"
            #                     end
            #                 end
            #
            #                 feature 'when the same issue has been logged by different scans' do
            #                     let(:sibling) do
            #                         issue  = site.entries.last
            #
            #                         set_sitemap_entries other_revision.entries.create(
            #                             type:           issue.type,
            #                             page:           FactoryGirl.create(:issue_page),
            #                             referring_page: FactoryGirl.create(:issue_page),
            #                             input_vector:         FactoryGirl.create(:input_vector).
            #                                                 tap { |v| v.action = issue.sitemap_entry.url },
            #                             sitemap_entry:  issue.sitemap_entry,
            #                             digest:         issue.digest,
            #                             state:          'trusted'
            #                         )
            #                     end
            #
            #                     before do
            #                         sibling
            #                         visit current_url
            #                     end
            #
            #                     scenario 'user sees scan name' do
            #                         expect(entries.find("#summary-issue-#{sibling.digest}")).to have_content sibling.revision.scan.name
            #                     end
            #
            #                     scenario 'user sees revision link with filtering options' do
            #                         path = site_scan_revision_path( sibling.revision.scan.site, sibling.revision.scan, sibling.revision )
            #                         expect(entries.find("#summary-issue-#{sibling.digest}")).to have_xpath "//a[starts-with(@href, '#{path}?filter')]"
            #                     end
            #
            #                     scenario 'user sees revision index' do
            #                         expect(entries.find("#summary-issue-#{sibling.digest}")).to have_content sibling.revision.index
            #                     end
            #
            #                     scenario 'user sees revision link with filtering options' do
            #                         expect(entries.find("#summary-issue-#{sibling.digest}")).to have_xpath "//a[starts-with(@href, '#{site_scan_revision_path(sibling.revision.scan.site, sibling.revision.scan, sibling.revision)}?filter')]"
            #                     end
            #                 end
            #             end
            #
            #             scenario 'users sees link to the Issue page' do
            #                 site.entries.each do |issue|
            #                     path = site_scan_revision_issue_path(issue.revision.scan.site, issue.revision.scan, issue.revision, issue)
            #                     expect(entries.find("#summary-issue-#{issue.digest}")).to have_xpath "//a[@href='#{path}']"
            #                 end
            #             end
            #
            #             scenario 'user sees vector type' do
            #                 site.entries.each do |issue|
            #                     expect(entries.find("#summary-issue-#{issue.digest}")).to have_content issue.input_vector.kind
            #                 end
            #             end
            #
            #             feature 'different from the referring page' do
            #                 before do
            #                     issue
            #                     visit site_path( site )
            #                 end
            #
            #                 let(:issue) do
            #                     issue = revision.entries.create(
            #                         type:           types.first,
            #                         page:           FactoryGirl.create(:issue_page),
            #                         referring_page: FactoryGirl.create(:issue_page),
            #                         input_vector:         FactoryGirl.create(:input_vector, affected_input_name: 'stuff'),
            #                         sitemap_entry:  site.sitemap_entries.first,
            #                         digest:         rand(99999999999999),
            #                         state:          'trusted'
            #                     )
            #
            #                     issue.referring_page.dom.url = "#{issue.input_vector.action}/2"
            #                     issue.referring_page.dom.save
            #                     set_sitemap_entries issue
            #                 end
            #
            #                 scenario 'user sees vector action URL without scheme, host and port' do
            #                     url = ApplicationHelper.url_without_scheme_host_port( issue.input_vector.action )
            #                     expect(entries.find("#summary-issue-#{issue.digest}")).to have_content url
            #                 end
            #             end
            #
            #             feature 'when the vector has an affected input' do
            #                 before do
            #                     issue
            #                     visit site_path( site )
            #                 end
            #
            #                 let(:issue) do
            #                     set_sitemap_entries revision.entries.create(
            #                         type:           types.first,
            #                         page:           FactoryGirl.create(:issue_page),
            #                         referring_page: FactoryGirl.create(:issue_page),
            #                         input_vector:         FactoryGirl.create(:input_vector, affected_input_name: 'stuff'),
            #                         sitemap_entry:  site.sitemap_entries.first,
            #                         digest:         rand(99999999999999),
            #                         state:          'trusted'
            #                     )
            #                 end
            #
            #                 scenario 'it includes input info' do
            #                     expect(entries.find("#summary-issue-#{issue.digest}")).to have_content issue.input_vector.affected_input_name
            #                 end
            #             end
            #
            #             feature 'when the vector does not have an affected input' do
            #                 before do
            #                     issue
            #                     visit site_path( site )
            #                 end
            #
            #                 let(:issue) do
            #                     set_sitemap_entries revision.entries.create(
            #                         type:           types.first,
            #                         page:           FactoryGirl.create(:issue_page),
            #                         referring_page: FactoryGirl.create(:issue_page),
            #                         input_vector:         FactoryGirl.create(:input_vector, affected_input_name: nil),
            #                         sitemap_entry:  site.sitemap_entries.first,
            #                         digest:         rand(99999999999999),
            #                         state:          'trusted'
            #                     )
            #                 end
            #
            #                 scenario 'it does not include input info' do
            #                     expect(entries.find("#summary-issue-#{issue.digest}")).to_not have_content 'input'
            #                 end
            #             end
            #         end
            #     end
            # end
            #
            # feature 'statistics' do
            #     let(:statistics) { find '#summary-statistics' }
            #
            #     scenario 'user sees amount of pages with entries' do
            #         expect(statistics).to have_text "#{site.sitemap_entries.with_issues.size} pages with entries"
            #     end
            #
            #     scenario 'user sees total amount of pages' do
            #         expect(statistics).to have_text "out of #{site.reload.sitemap_entries.size}"
            #     end
            #
            #     scenario 'user sees amount of entries' do
            #         expect(statistics).to have_text "#{site.entries.size} entries"
            #     end
            #
            #     scenario 'user sees maximum severity of entries' do
            #         expect(statistics).to have_text "maximum severity of #{site.entries.max_severity.capitalize}"
            #     end
            #
            #     scenario 'user sees amount of scan revisions' do
            #         expect(statistics).to have_text "#{site.reload.revisions.size} revision"
            #     end
            #
            #     scenario 'user sees amount of scans' do
            #         expect(statistics).to have_text "#{site.reload.scans.size} scan"
            #     end
            #
            #     scenario 'user sees amount of entries by severity' do
            #         IssueTypeSeverity::SEVERITIES.each do |severity|
            #             elem = statistics.find(".text-severity-#{severity}")
            #
            #             expectation =
            #                 "#{site.entries.send("#{severity}_severity").size} #{severity}"
            #
            #             expect(elem).to have_text expectation
            #         end
            #     end
            # end

            feature 'sitemap' do
                let(:sitemap) { find '#summary-sitemap' }

                scenario 'entries filter entries'
                scenario 'entries filter scans'

                scenario 'URLs are color-coded by max severity'
                scenario 'shows amount of entries per entry'

                scenario 'user sees amount of pages' do
                    expect(sitemap.find('#sitemap-entry-all')).to have_text site.sitemap_entries.with_issues.size
                end

                scenario 'includes pages with entries' do
                    site.sitemap_entries.with_issues.each do |entry|
                        expect(sitemap).to have_text ApplicationHelper.url_without_scheme_host_port( entry.url )
                    end
                end

                feature 'when filtering criteria exclude some entries' do
                    scenario 'the shown info only refers to the included entries'
                end

                feature 'when no entry is selected' do
                    scenario 'the All link is .active' do
                        expect(sitemap.find( '#sitemap-entry-all' )[:class]).to include 'active'
                    end
                end

                feature 'when an entry is selected' do
                    scenario 'becomes .active'
                end
            end
        end

        # feature 'without entries' do
        #     scenario 'shows notice'
        #
        #     feature 'and a filtered page' do
        #         feature 'which has entries' do
        #             scenario 'lists revisions which have entries for it'
        #             scenario 'lists scans which have entries for it'
        #         end
        #     end
        # end
    end
end
