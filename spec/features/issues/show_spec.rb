include Warden::Test::Helpers
Warden.test_mode!

feature 'Issue page' do

    let(:user) { FactoryGirl.create :user, sites: [site] }
    let(:digest) { rand(999999999) }
    let(:type) { FactoryGirl.create(:issue_type) }
    let(:issue) do
        Issue.create_from_engine(
            Factory[:issue],
            digest: digest,
            revision: revision,
            type: type,
            platform: FactoryGirl.create(
                :issue_platform,
                type: FactoryGirl.create(:issue_platform_type)
            )
        )
    end
    let(:sibling) do
        Issue.create_from_engine(
            Factory[:issue],
            digest: digest,
            revision: revision,
            type: type
        )
    end

    let(:revision) { FactoryGirl.create :revision, scan: scan }
    let(:other_revision) { FactoryGirl.create :revision, scan: other_scan }
    let(:other_scan) { FactoryGirl.create :scan, site: site, profile: FactoryGirl.create(:profile) }
    let(:scan) { FactoryGirl.create :scan, site: site, profile: FactoryGirl.create(:profile) }
    let(:site) { FactoryGirl.create :site }
    let(:input_vector) { issue.input_vector }

    def refresh
        visit site_scan_revision_issue_path( site, scan, revision, issue )
    end

    after(:each) do
        Warden.test_reset!
    end

    before do
        user.sites << site
        login_as user, scope: :user
        refresh
    end

    it_behaves_like 'Scan sidebar', without_site_buttons: true

    scenario 'has title' do
        expect(page).to have_title issue.to_s
        expect(page).to have_title revision.to_s
        expect(page).to have_title scan.name
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

        expect(breadcrumbs.find('li:nth-of-type(5)')).to have_content scan.to_s
        expect(breadcrumbs.find('li:nth-of-type(5) a').native['href']).to eq site_scan_path( site, scan )

        expect(breadcrumbs.find('li:nth-of-type(6)')).to have_content revision.to_s
        expect(breadcrumbs.find('li:nth-of-type(6) a').native['href']).to eq site_scan_revision_path( site, scan, revision )

        expect(breadcrumbs.find('li:nth-of-type(7)')).to have_content issue.to_s
        expect(breadcrumbs.find('li:nth-of-type(7) a').native['href']).to eq site_scan_revision_issue_path( site, scan, revision, issue )
    end

    feature 'page header' do
        let(:header) { find '.page-header' }

        feature 'heading' do
            let(:heading) { header.find 'h1' }

            feature 'contains' do
                scenario 'issue type name' do
                    expect(heading).to have_content issue.type.name
                end

                scenario 'vector type' do
                    expect(heading).to have_content issue.input_vector.kind
                end

                scenario 'affected input name' do
                    expect(heading).to have_content issue.input_vector.affected_input_name
                end

                scenario 'vector action link' do
                    expect(heading).to have_xpath "//a[@href='#{issue.input_vector.action}']"
                end

                scenario 'preferring page link' do
                    expect(heading).to have_xpath "//a[@href='#{issue.referring_page.dom.url}']"
                end
            end
        end

        scenario 'has severity label' do
            expect(header.find("p.label-severity-#{issue.type.severity}")).to have_content "#{issue.type.severity.capitalize} severity"
        end
    end

    feature 'sidebar' do
        let(:sidebar) { find '#sidebar' }

        feature 'when there are siblings' do
            let(:siblings) { find '#sidebar-issue-siblings' }

            before do
                sibling
                refresh
            end

            scenario 'links to them' do
                path = site_scan_revision_issue_path(
                    site,
                    sibling.revision.scan,
                    sibling.revision,
                    sibling
                )

                expect(siblings).to have_content "#{sibling.revision} of #{sibling.revision.scan}"
                expect(siblings).to have_xpath "//a[@href='#{path}']"
            end
        end

        feature 'when reviewed by a revision' do
            scenario 'it does not show the relevant info' do
                expect(sidebar).to_not have_css '#reviewed-by-revision'
            end
        end

        feature 'when reviewed by a revision' do
            let(:reviewed_by_revision) { sidebar.find '#reviewed-by-revision' }

            before do
                issue.state = 'fixed'
                issue.reviewed_by_revision = revision
                issue.save

                refresh
            end

            scenario 'shows a link to the revision' do
                expect(reviewed_by_revision.find('.label-info')).to have_xpath "a[@href='#{reviews_site_scan_revision_path( site, scan, revision )}']"
            end

            feature 'when the revision is from the same scan' do
                scenario 'does not show the scan' do
                    expect(reviewed_by_revision.find('.label-info')).to_not have_xpath "a[@href='#{site_scan_path( site, scan )}']"
                end
            end

            feature 'when the revision is from a different scan' do
                before do
                    issue.state = 'fixed'
                    issue.reviewed_by_revision = other_revision
                    issue.save

                    refresh
                end

                scenario 'shows a link the scan' do
                    expect(reviewed_by_revision.find('.label-info')).to have_xpath "//a[@href='#{site_scan_path( site, other_scan )}']"
                end
            end
        end

        feature 'form', js: true do
            before do
                sibling
                refresh
            end

            scenario 'can set the state' do
                select 'Fixed', from: 'issue_state'
                sleep 1

                expect(issue.reload.state).to eq 'fixed'
            end

            scenario 'sets the state for sibling entries too' do
                select 'Fixed', from: 'issue_state'
                sleep 1

                expect(sibling.reload.state).to eq 'fixed'
            end
        end

        context 'when the issue has #proof' do
            it 'shows Identification'
        end

        context 'when the issue has a page with execution flow sinks' do
            it 'shows Identification'
        end

        context 'when the issue has no proof data' do
            it 'does not show Identification'
        end
    end

    feature 'info' do
        let(:info) { find '#info' }

        scenario 'has rendered Markdown description' do
            issue.type.description = '**Stuff**'
            issue.type.save

            refresh

            expect(info.find('.description strong')).to have_content 'Stuff'
        end

        feature 'when there are no siblings' do
            scenario 'does not show list' do
                expect(info).to_not have_css '#siblings'
            end
        end

        feature 'when there is a CWE' do
            scenario 'shows it as a reference' do
                issue.type.cwe = 1
                issue.type.references = []
                issue.type.save

                refresh

                references = info.find('.references')

                expect(references).to have_content 'CWE'
                expect(references).to have_xpath "//a[@href='#{issue.type.cwe_url}']"
            end
        end

        feature 'when there are references' do
            scenario 'shows them' do
                references = info.find('.references')

                expect(issue.type.references.size).to be >= 1

                issue.type.references.each do |reference|
                    expect(references).to have_xpath "//a[@href='#{reference.url}']"
                    expect(references).to have_content reference.title
                end
            end
        end

        feature 'when there are no references' do
            scenario 'shows nothing' do
                issue.type.cwe = nil
                issue.type.references = []
                issue.type.save

                refresh

                expect(info).to_not have_css '.references'
            end
        end
    end

    feature 'input vector' do
        let(:input_vector_div) { find '#input_vector' }

        feature 'when the input vector has no source' do
            before do
                input_vector.source = nil
                input_vector.save

                refresh
            end

            scenario 'it does not show it' do
                expect(input_vector_div).to_not have_css '.source'
            end
        end

        feature 'when the input vector has source' do
            let(:source) { input_vector_div.find('.source') }

            before do
                input_vector.source = '<form></form>'
                input_vector.save

                refresh
            end

            scenario 'it highlights it' do
                expect(source).to have_css '.CodeRay'
                expect(source).to have_content input_vector.source
            end
        end

        feature 'info' do
            let(:info) { input_vector_div.find '.input_vector-info' }

            scenario 'has vector type' do
                expect(info).to have_content input_vector.kind
            end

            feature 'when the issue is active' do
                before do
                    issue.active = true
                    issue.save

                    refresh
                end

                scenario 'has HTTP method' do
                    expect(info).to have_content input_vector.http_method
                end
            end

            feature 'when the issue is not active' do
                before do
                    issue.active = false
                    issue.save

                    refresh
                end

                scenario 'has HTTP method' do
                    expect(info).to_not have_content input_vector.http_method
                end
            end

            scenario 'has referring page URL' do
                expect(info).to have_xpath "//a[@href='#{issue.referring_page.dom.url}']"
            end

            scenario 'has vector action' do
                expect(info).to have_xpath "//a[@href='#{input_vector.action}']"
            end
        end

        feature 'when it has inputs' do
            before do
                input_vector.default_inputs = {
                    'myname'  => 'my value',
                    'myname1' => 'my value2'
                }
                input_vector.save

                refresh
            end

            let(:values) { input_vector_div.find '.input_vector-values .table-hash' }

            scenario 'it shows values' do
                input_vector.default_inputs.each do |k, v|
                    expect(values).to have_content k
                    expect(values).to have_content v
                end
            end

            feature 'when the issue has an affected input name' do
                before do
                    input_vector.affected_input_name = 'myname'
                    input_vector.save

                    refresh
                end

                scenario 'it highlights the input' do
                    row = values.find('tr:nth-of-type(1)')

                    expect(row.find('th:nth-of-type(1)')).to have_content 'myname'
                    expect(row.find('th:nth-of-type(2)')).to have_content '='
                    expect(row.find('th:nth-of-type(3)')).to have_content 'my value'

                    expect(values.find('tr:nth-of-type(2)')).to_not have_xpath 'th'
                end
            end
        end

        feature 'when it has no inputs' do
            before do
                input_vector.default_inputs = {}
                input_vector.save

                refresh
            end

            scenario 'it does not show values' do
                expect(input_vector_div).to_not have_css '.input_vector-values'
            end
        end
    end

    feature 'reproduction' do
        let(:reproduction) { find '#reproduction' }

        feature 'when the scan was performed as a non-Guest role' do
            let(:role_info) { reproduction.find '#reproduction-site-role' }

            scenario 'shows a notice' do
                expect(role_info).to have_content scan.site_role.name
            end
        end

        feature 'when the scan was performed as a Guest role' do
            before do
                scan.site_role = FactoryGirl.create( :site_role, login_type: 'none' )
                scan.save

                refresh
            end

            scenario 'does not show notice' do
                expect(reproduction).to_not have_css '#reproduction-site-role'
            end
        end

        feature 'when the issue is active' do
            before do
                issue.active = true
                issue.save
            end

            feature 'and has inputs' do
                before do
                    input_vector.inputs = {
                        'myname'  => 'my value',
                        'myname1' => 'my value2'
                    }
                    input_vector.save

                    refresh
                end

                let(:values){ reproduction.find( '#reproduction-inputs .table-hash' ) }

                scenario 'it shows values' do
                    input_vector.inputs.each do |k, v|
                        expect(values).to have_content k
                        expect(values).to have_content v
                    end
                end

                feature 'when the issue has an affected input name' do
                    before do
                        input_vector.affected_input_name = 'myname'
                        input_vector.save

                        refresh
                    end

                    scenario 'it highlights the input' do
                        row = values.find('tr:nth-of-type(1)')

                        expect(row.find('th:nth-of-type(1)')).to have_content 'myname'
                        expect(row.find('th:nth-of-type(2)')).to have_content '='
                        expect(row.find('th:nth-of-type(3)')).to have_content 'my value'

                        expect(values.find('tr:nth-of-type(2)')).to_not have_xpath 'th'
                    end
                end
            end

            feature 'and has no inputs' do
                before do
                    input_vector.inputs = {}
                    input_vector.save

                    refresh
                end

                scenario 'it shows no inputs' do
                    expect(reproduction).to_not have_css '#reproduction-inputs'
                end
            end
        end

        feature 'when the issue is not active' do
            before do
                issue.active = false
                issue.save

                refresh
            end

            scenario 'it shows no inputs' do
                expect(reproduction).to_not have_css '#reproduction-inputs'
            end
        end

        feature 'when the issue has transitions' do
            let(:dom_transitions) { issue.page.dom.transitions }
            let(:transitions) { find '#reproduction-transitions' }

            scenario 'it lists them' do
                expect(dom_transitions.size).to be >= 1

                cnt = 1
                dom_transitions.each.with_index do |t, i|
                    next if t.event == :request

                    row = transitions.find( ".table-transitions > tbody > tr:nth-of-type(#{cnt})" )

                    expect(row).to have_content t.event
                    expect(row).to have_content t.element
                    expect(row).to_not have_content t.time

                    cnt += 1
                end
            end

            scenario 'it ignores request ones' do
                expect(dom_transitions.find { |t| t.event == :request }).to be_truthy
                expect(transitions).to_not have_content 'request'
            end

            feature 'when a transition has option' do
                scenario 'url' do
                    transition = dom_transitions[0]
                    row        = transitions.find( '.table-transitions > tbody > tr:nth-of-type(1)' )
                    options    = row.find( 'table.table-transition-options > tr:nth-of-type(1)' )

                    expect(options.find('th')).to have_content 'URL'
                    expect(options.find('td')).to have_content transition.options['url']
                end

                scenario 'cookies' do
                    transition = dom_transitions[0]
                    row        = transitions.find( '.table-transitions > tbody > tr:nth-of-type(1)' )
                    options    = row.find( 'table.table-transition-options' )

                    expect(options.find('tr:nth-of-type(2) th')).to have_content 'Cookies'

                    cookies_table = options.find('tr:nth-of-type(3) td table')

                    transition.options['cookies'].each do |k, v|
                        expect(cookies_table).to have_content k
                        expect(cookies_table).to have_content v
                    end
                end

                scenario 'value' do
                    transition = dom_transitions[2]
                    row        = transitions.find( '.table-transitions > tbody > tr:nth-of-type(2)' )
                    options    = row.find( 'table.table-transition-options > tr:nth-of-type(1)' )

                    expect(options.find('th')).to have_content 'Value'
                    expect(options.find('td')).to have_content transition.options['value'].strip
                end

                scenario 'inputs' do
                    transition = dom_transitions[3]
                    row        = transitions.find( '.table-transitions > tbody > tr:nth-of-type(3)' )
                    options    = row.find( 'table.table-transition-options' )

                    expect(options.find('tr:nth-of-type(1) th')).to have_content 'Inputs'

                    inputs_table = options.find('tr:nth-of-type(2) td table')

                    transition.options['inputs'].each do |k, v|
                        expect(inputs_table).to have_content k.strip
                        expect(inputs_table).to have_content v.strip
                    end
                end
            end

            scenario 'it does not show HTTP request' do
                expect(reproduction).to_not have_css '#reproduction-request'
            end
        end

        feature 'when the issue has no transition' do
            before do
                issue.page.dom.transitions = []
                issue.page.dom.save

                issue.page.request.raw = 'stuff goes here'
                issue.page.request.save

                issue.input_vector.seed = nil
                issue.input_vector.save

                refresh
            end

            let(:request) { reproduction.find '#reproduction-request' }

            scenario 'it does not show transitions' do
                expect(reproduction).to_not have_css '#reproduction-transitions'
            end

            scenario 'it shows HTTP request' do
                expect(request).to have_content issue.page.request.to_s
            end

            feature 'when the request includes the seed' do
                before do
                    issue.input_vector.seed = 'goes'
                    issue.input_vector.save

                    refresh
                end

                scenario 'it highlights it' do
                    expect(request.find('.highlight')).to have_content issue.input_vector.seed
                end
            end
        end
    end

    feature 'identification' do
        let(:identification) { find '#identification' }

        feature 'when the issue has platforms' do
            let(:platform) { identification.find '#identification-platform' }

            scenario 'it shows platform info' do
                expect(platform).to have_content issue.platform.name
                expect(platform).to have_content issue.platform.type.name
            end
        end

        feature 'when the issue has no platforms' do
            before do
                issue.platform = nil
                issue.save

                refresh
            end

            scenario 'it does not show platform info' do
                expect(identification).to_not have_css '#identification-platform'
            end
        end

        feature 'when the issue has remarks' do
            before do
                issue.remarks = []
                issue.remarks.create author: 'the_dude', text: 'stuff'
                issue.remarks.create author: 'the_dude', text: 'stuff 2'
                issue.remarks.create author: 'the_other_dude', text: 'stuff'
                issue.remarks.create author: 'the_other_dude', text: 'stuf2'
                issue.save

                refresh
            end

            let(:remarks) { identification.find '#identification-remarks' }

            scenario 'it shows them in groups' do
                dude = remarks.find('ul.list-unstyled > li:nth-of-type(1)')
                expect(dude.find('strong')).to have_content 'The dude'

                dude_texts = dude.find( 'ul' )
                expect(dude_texts.find( 'li:nth-of-type(1)' )).to have_content issue.remarks[0].text
                expect(dude_texts.find( 'li:nth-of-type(2)' )).to have_content issue.remarks[1].text

                other_dude = remarks.find('ul.list-unstyled > li:nth-of-type(2)')
                expect(other_dude.find('strong')).to have_content 'The other dude'

                other_dude_texts = other_dude.find( 'ul' )
                expect(other_dude_texts.find( 'li:nth-of-type(1)' )).to have_content issue.remarks[2].text
                expect(other_dude_texts.find( 'li:nth-of-type(2)' )).to have_content issue.remarks[3].text
            end
        end

        feature 'when the issue has no remarks' do
            before do
                issue.remarks = []
                issue.save

                refresh
            end

            scenario 'it does not show remarks' do
                expect(identification).to_not have_css '#identification-remarks'
            end
        end

        feature 'when the issue has a proof and a response' do
            let(:proof) { identification.find '#identification-proof.issue-proof' }

            before do
                issue.proof = 'this is the proof'
                issue.save

                issue.page.response.body = "This is the response and #{issue.proof}."
                issue.page.response.save

                issue.page.dom.body = "This is the DOM body and #{issue.proof}."
                issue.page.dom.save

                refresh
            end

            feature 'and transitions' do
                before do
                    expect(issue.page.dom.transitions).to be_any
                end

                feature 'and the page DOM body includes the proof' do
                    scenario 'highlights the proof in the body' do
                        expect(proof.find('.highlight-container')).to have_content issue.page.dom.body
                        expect(proof.find('.highlight-container .highlight')).to have_content issue.proof
                    end
                end

                feature 'and the page DOM body does not include the proof' do
                    before do
                        issue.proof = 'response and this is the proof'
                        issue.save

                        refresh
                    end

                    feature 'and the response includes the proof' do
                        scenario 'highlights the proof in the response' do
                            expect(proof.find('.highlight-container')).to have_content issue.page.response.to_s
                            expect(proof.find('.highlight-container .highlight')).to have_content issue.proof
                        end
                    end

                    feature 'and the response does not include the proof' do
                        before do
                            issue.proof = '<weird>stuff</weird>'
                            issue.save

                            refresh
                        end

                        scenario 'displays proof as highlighted code' do
                            expect(proof.find('.CodeRay')).to have_content issue.proof
                        end
                    end
                end
            end

            feature 'and no transitions' do
                before do
                    issue.page.dom.transitions = []
                    issue.page.dom.save
                    refresh
                end

                feature 'and the response includes the proof' do
                    scenario 'highlights the proof in the response' do
                        expect(proof.find('.highlight-container')).to have_content issue.page.response.to_s
                        expect(proof.find('.highlight-container .highlight')).to have_content issue.proof
                    end
                end

                feature 'and the response does not include the proof' do
                    before do
                        issue.proof = '<weird>stuff</weird>'
                        issue.save

                        refresh
                    end

                    scenario 'displays proof as highlighted code' do
                        expect(proof.find('.CodeRay')).to have_content issue.proof
                    end
                end
            end
        end

        feature 'when the issue has no proof' do
            before do
                issue.proof = nil
                issue.save

                refresh
            end

            scenario 'it does not show issue proof' do
                expect(identification).to_not have_css '#identification-proof.issue-proof'
            end
        end

        feature 'when the issue has no response' do
            before do
                issue.page.response.raw_headers = nil
                issue.page.response.body        = nil
                issue.page.response.save

                refresh
            end

            scenario 'it does not show issue proof' do
                expect(identification).to_not have_css '#identification-proof.issue-proof'
            end
        end

        feature 'when the issue has JS execution flow sinks' do
            let(:sinks) { identification.find '#identification-execution-flow-sinks' }

            scenario 'it includes JS execution flow sinks' do
                expect(sinks).to have_css 'table.table-execution-flow-sinks'
            end
        end

        feature 'when the issue has no JS execution flow sinks' do
            before do
                issue.page.dom.execution_flow_sinks = []
                issue.page.dom.save

                refresh
            end

            scenario 'it does not show them' do
                expect(identification).to_not have_css '#identification-execution-flow-sinks'
            end
        end

        feature 'when the issue has only remarks as proof' do
            before do
                issue.proof = nil
                issue.save

                issue.page.dom.execution_flow_sinks = []
                issue.page.dom.save

                refresh
            end

            scenario 'shows them' do
                expect(identification).to have_css '#identification-remarks'
            end
        end

        feature 'when the issue has no associated proof of any kind' do
            before do
                issue.proof = nil
                issue.remarks = []
                issue.save

                issue.page.dom.execution_flow_sinks = []
                issue.page.dom.save

                refresh
            end

            scenario 'it does not show issue identification info' do
                expect(page).to_not have_css '#identification'
            end
        end
    end

    feature 'remediation' do
        let(:remediation) { find '#remediation' }

        scenario 'shows rendered Markdown description' do
            issue.type.remedy_guidance = '**Stuff**'
            issue.type.save

            refresh

            expect(remediation.find('.description strong')).to have_content 'Stuff'
        end

        feature 'when there are references' do
            scenario 'shows them' do
                references = remediation.find('.references')

                expect(issue.type.references.size).to be >= 1

                issue.type.references.each do |reference|
                    expect(references).to have_xpath "//a[@href='#{reference.url}']"
                    expect(references).to have_content reference.title
                end
            end
        end

        feature 'when there are no references' do
            scenario 'shows nothing' do
                issue.type.cwe = nil
                issue.type.references = []
                issue.type.save

                refresh

                expect(remediation).to_not have_css '.references'
            end
        end

        feature 'when the issue has JS data flow sinks' do
            let(:sinks) { remediation.find '#remediation-data-flow-sinks' }

            scenario 'it includes JS data flow sinks' do
                expect(sinks).to have_css 'table.table-data-flow-sinks'
            end
        end

        feature 'when the issue has no JS data flow sinks' do
            before do
                issue.page.dom.data_flow_sinks = []
                issue.page.dom.save

                refresh
            end

            scenario 'it does not show them' do
                expect(remediation).to_not have_css '#remediation-data-flow-sinks'
            end
        end
    end

    feature 'advanced' do
        let(:advanced) { find '#advanced' }

        feature 'affected page' do
            let(:affected_page) { advanced.find '#advanced_affected_page' }

            feature 'when it has HTTP traffic' do
                before do
                    issue.page.request.raw = 'GET /stuff HTTP/1.1'
                    issue.page.request.save

                    issue.page.response.body = '<stuff></stuff>'
                    issue.page.response.save

                    refresh
                end

                let(:http_traffic) { affected_page.find '#advanced_affected_page-http-traffic' }

                feature 'request' do
                    let(:request) { http_traffic.find '#advanced_affected_page-http-traffic-request' }

                    scenario 'shows traffic' do
                        expect(request).to have_content issue.page.request.to_s
                    end

                    feature 'when it includes the vector seed' do
                        before do
                            issue.input_vector.seed = 'stuff'
                            issue.input_vector.save

                            refresh
                        end

                        scenario 'it highlights it' do
                            expect(request.find('.highlight')).to have_content issue.input_vector.seed
                        end
                    end
                end

                feature 'response' do
                    let(:response) { http_traffic.find '#advanced_affected_page-http-traffic-response' }

                    scenario 'shows traffic' do
                        expect(response).to have_content issue.page.response.to_s
                    end

                    feature 'when it includes the issue proof' do
                        before do
                            issue.proof = '<stuff>'
                            issue.save

                            refresh
                        end

                        scenario 'it highlights it' do
                            expect(response.find('.highlight')).to have_content issue.proof
                        end
                    end
                end
            end

            feature 'when there is no HTTP traffic' do
                before do
                    issue.page.request.raw = ''
                    issue.page.request.save

                    issue.page.response.body = ''
                    issue.page.response.save

                    refresh
                end

                scenario 'it does not show HTTP traffic' do
                    expect(affected_page).to_not have_css '#advanced_affected_page-http-traffic'
                end
            end

            feature 'DOM processing' do
                let(:dom_data) { affected_page.find '#advanced_affected_page-dom' }

                feature 'when it has transitions' do
                    scenario 'it lists them' do
                        expect(dom_data).to have_css 'table.table-transitions'
                    end

                    feature 'when it has a DOM body' do
                        before do
                            issue.page.dom.body = <<EOHTML
<html>
    <title>My title!</title>
    <body>
        <div>
            My stuff!
        </div>
    </body>
</html>
EOHTML
                            issue.page.dom.save
                        end

                        let(:states) { affected_page.find '#advanced_affected_page-dom-states' }

                        feature 'different from the response body' do
                            before do
                                issue.page.response.body = <<EOHTML
<html>
    <title>My other title!</title>
    <body>
        <div>
            My other stuff!
        </div>
    </body>
</html>
EOHTML
                                issue.page.response.save

                                refresh
                            end

                            let(:initial) { states.find('#advanced_affected_page_dom_processing_initial') }
                            let(:final) { states.find('#advanced_affected_page_dom_processing_final') }
                            let(:diff) do
                                states.find('#advanced_affected_page_dom_processing_diff .code').native.to_s + "\n"
                            end

                            scenario 'it displays the response body' do
                                expect(initial.native.to_s.gsub( /\s/, '')).to have_content issue.page.response.body.gsub( /\s/, '')
                            end

                            scenario 'it displays the page DOM body' do
                                expect(final.native.to_s.gsub( /\s/, '')).to have_content issue.page.dom.body.gsub( /\s/, '')
                            end

                            scenario 'it displays a diff' do
                                expect(diff).to eq <<EOHTML
<td class="code with-line-numbers">
<pre><div id="advanced_affected_page_dom_processing-diff-0" class="diff diff-unchanged"> <span class="tag">&lt;html&gt;</span>
</div><div id="advanced_affected_page_dom_processing-diff-1" class="diff diff-deletion">    <span class="tag">&lt;title&gt;</span>My other title!<span class="tag">&lt;/title&gt;</span>
</div><div id="advanced_affected_page_dom_processing-diff-2" class="diff diff-addition">    <span class="tag">&lt;title&gt;</span>My title!<span class="tag">&lt;/title&gt;</span>
</div><div id="advanced_affected_page_dom_processing-diff-3" class="diff diff-unchanged">     <span class="tag">&lt;body&gt;</span>
</div><div id="advanced_affected_page_dom_processing-diff-4" class="diff diff-unchanged">         <span class="tag">&lt;div&gt;</span>
</div><div id="advanced_affected_page_dom_processing-diff-5" class="diff diff-deletion">            My other stuff!
</div><div id="advanced_affected_page_dom_processing-diff-6" class="diff diff-addition">            My stuff!
</div><div id="advanced_affected_page_dom_processing-diff-7" class="diff diff-unchanged">         <span class="tag">&lt;/div&gt;</span>
</div><div id="advanced_affected_page_dom_processing-diff-8" class="diff diff-unchanged">     <span class="tag">&lt;/body&gt;</span>
</div><div id="advanced_affected_page_dom_processing-diff-9" class="diff diff-unchanged"> <span class="tag">&lt;/html&gt;</span>
</div><div id="advanced_affected_page_dom_processing-diff-10" class="diff diff-addition">
</div></pre>
        </td>
EOHTML
                            end
                        end

                        feature 'identical to the response body' do
                            before do
                                issue.page.response.body = issue.page.dom.body
                                issue.page.response.save

                                refresh
                            end

                            scenario 'does not show DOM states' do
                                expect(affected_page).to_not have_css '#advanced_affected_page-dom-states'
                            end
                        end
                    end
                end

                feature 'when it has no transitions' do
                    before do
                        issue.page.dom.transitions = []
                        issue.page.dom.save

                        refresh
                    end

                    scenario 'it does not show DOM data' do
                        expect(affected_page).to_not have_css '#advanced_affected_page-dom'
                    end
                end
            end

            feature 'execution flow sinks' do
                feature 'when there are any' do
                    scenario 'it lists them' do
                        expect(affected_page).to have_css 'table.table-execution-flow-sinks'
                    end
                end

                feature 'when there are none' do
                    before do
                        issue.page.dom.execution_flow_sinks = []
                        issue.page.dom.save

                        refresh
                    end

                    scenario 'is does not list them' do
                        expect(affected_page).to_not have_css 'table.table-execution-flow-sinks'
                    end
                end
            end

            feature 'data flow sinks' do
                feature 'when there are any' do
                    scenario 'it lists them' do
                        expect(affected_page).to have_css 'table.table-data-flow-sinks'
                    end
                end

                feature 'when there are none' do
                    before do
                        issue.page.dom.data_flow_sinks = []
                        issue.page.dom.save

                        refresh
                    end

                    scenario 'is does not list them' do
                        expect(affected_page).to_not have_css 'table.table-data-flow-sinks'
                    end
                end
            end
        end
    end

end
