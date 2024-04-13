describe ScanScheduler::Helpers::Scan do
    subject { ScanScheduler.instance }

    let(:other_site) { FactoryGirl.create :site, user: user }
    let(:other_scan) do
        FactoryGirl.create(
            :scan,
            site: other_site,
            profile: profile,
            site_role: site_role,
            schedule: FactoryGirl.create(
                      :schedule,
                      start_at: Time.now
                  )
        )
    end

    let(:other_revision) { new_revision }
    let(:revision) { new_revision }
    let(:scan) do
        FactoryGirl.create(
            :scan,
            site: site,
            profile: profile,
            site_role: site_role,
            schedule: FactoryGirl.create(
                :schedule,
                start_at: Time.now
            )
        )
    end
    let(:user) { FactoryGirl.create :user }
    let(:settings){ Settings }
    let(:profile) { FactoryGirl.create :profile }
    let(:site_role) { FactoryGirl.create :site_role, site: site }
    let(:site) { FactoryGirl.create :site, user: user }
    let(:instance_manager) { MockInstanceManager.new }
    let(:native_issue) { Factory[:issue] }
    let(:tick) { ScanScheduler::TICK }
    let(:instance) do
        instance = nil
        subject.spawn_instance_for( revision ) { |i| instance = i }
        instance
    end
    let(:statistics) do
        {
            http:          {
                request_count:               120209,
                response_count:              120209,
                time_out_count:              162,
                total_responses_per_second:  41.08373646212503,
                burst_response_time_sum:     3.963999,
                burst_response_count:        18,
                burst_responses_per_second:  20.98328921971754,
                burst_average_response_time: 0.22022216666666666,
                total_average_response_time: 0.3961567054297138,
                max_concurrency:             10,
                original_max_concurrency:    20
            },
            runtime:       2.hours.to_i,
            found_pages:   84,
            audited_pages: 569,
            current_page:  'http://stuff.com/path/here/'
        }
    end
    let(:performance_snapshot_attributes) do
        PerformanceSnapshot.engine_to_attributes( statistics )
    end

    def new_revision
        FactoryGirl.create :revision, scan: scan
    end

    def wait
        # q = nil
        # subject.after_next_tick { q = true }
        # sleep 0.5 while !q
        sleep tick
    end

    before do
        subject.reset
        allow(subject).to receive(:instances) { instance_manager }
    end

    after :each do
        subject.stop
        subject.instances.killall
    end

    describe "#{described_class}::REPORT_DIR" do
        it 'is a directory' do
            expect(File.directory?( described_class::REPORT_DIR )).to be_truthy
        end
    end

    describe '#suspend' do
        it 'suspends the scan' do
            expect(instance).to receive(:suspend)
            subject.suspend( revision )
        end
    end

    describe '#rescope' do
        before do
            instance
            expect(subject).to receive(:stop_monitor).with( revision )
        end

        it 'stops monitoring' do
            subject.rescope( revision )
        end

        it 'sets status to rescoped' do
            subject.rescope( revision )

            expect(revision).to be_rescoped
        end

        it 'sets stopped at to now' do
            now = Time.now

            subject.rescope( revision )

            expect(revision.stopped_at).to be > now
            expect(revision.stopped_at).to be < Time.now
        end

        it 'creates new revision' do
            subject.rescope( revision )

            expect(revision.next).to be_truthy
        end

        it 'new revision has the start time of the previous revision' do
            subject.rescope( revision )

            expect(revision.next.started_at.to_s).to eq revision.started_at.to_s
        end

        it 'new revision has status initialising' do
            subject.rescope( revision )

            expect(revision.next).to be_initializing
        end

        it 'updates options' do
            expect_any_instance_of(MockInstanceClientOptions).to receive(:set).with( scan.rpc_options )
            subject.rescope( revision )
        end

        it 'sets up progress monitoring' do
            expect(subject).to receive(:monitor) do |r|
                expect(r).to eq revision.next
            end

            subject.rescope( revision )
        end
    end

    describe '#restore' do
        let(:snapshot_path) { '/my/dir.afs' }

        before do
            revision.suspended!
            revision.snapshot_path = snapshot_path
            revision.save

            revision.update(
                started_at: Time.now - 1000,
                stopped_at: Time.now + 1000
            )

            allow(FileUtils).to receive(:rm).with(snapshot_path)
        end

        it 'spawns an instance' do
            expect(subject.active_instance_count).to be 0

            subject.restore( revision ) rescue Arachni::Reactor::Error::NotRunning

            expect(subject.active_instance_count).to be 1
        end

        it 'restores the scan' do
            expect_any_instance_of(MockInstanceClientService).to receive(:restore).with( revision.snapshot_path )
            subject.restore( revision )
        end

        it 'sets up progress monitoring' do
            subject.start

            expect(subject).to receive(:monitor) do |revision|
                expect(revision).to eq scan.revisions.reload.first
            end
            subject.restore( revision )
            wait
            wait
        end

        it 'sets status to restoring' do
            expect(revision).to receive(:restoring!)
            subject.restore( revision )
        end

        it 'removes #timed_out' do
            revision.timed_out = true
            revision.save

            subject.restore( revision ) rescue Arachni::Reactor::Error::NotRunning

            expect(revision).to_not be_timed_out
        end

        it 'deletes the snapshot' do
            expect(FileUtils).to receive(:rm).with(snapshot_path)
            subject.restore( revision )
        end

        it 'sets #started_at to now' do
            t = Time.now
            subject.restore( revision )

            expect(revision.started_at).to be > t
            expect(revision.started_at).to be < Time.now
        end

        it 'sets #stopped_at to nil' do
            subject.restore( revision )
            expect(revision.stopped_at).to be_nil
        end
    end

    describe '#pause' do
        it 'pauses the scan' do
            expect(instance).to receive(:pause)
            subject.pause( revision )
        end

        it 'passes the response to #handle_if_rpc_error' do
            instance

            expect(subject).to receive(:handle_if_rpc_error).with( revision, nil )
            subject.pause( revision )
        end
    end

    describe '#resume' do
        it 'resumes the scan' do
            expect(instance).to receive(:resume)
            subject.resume( revision )
        end

        it 'passes the response to #handle_if_rpc_error' do
            instance

            expect(subject).to receive(:handle_if_rpc_error).with( revision, nil )
            subject.resume( revision )
        end
    end

    describe '#abort' do
        before do
            instance
            expect(subject).to receive(:stop_monitor).with( revision )
            expect(subject).to receive(:download_report_and_shutdown).
                                   with( revision, { mark_issues_fixed: false, status: 'aborted' } )
        end

        it 'sets status to aborting' do
            subject.abort( revision )
            expect(revision).to be_aborting
        end

        it 'aborts progress monitoring' do
            instance
            subject.abort( revision )
        end

        it 'calls #download_report_and_shutdown' do
            instance
            subject.abort( revision )
        end
    end

    describe '#each_due_scan' do
        context 'when there are due scans' do
            before do
                FactoryGirl.create(
                    :scan,
                    site: site,
                    schedule_attributes: {
                        start_at: Time.now + 1000
                    }
                )
            end

            let(:due) do
                FactoryGirl.create(
                    :scan,
                    site: site,
                    schedule_attributes: {
                        start_at: Time.now
                    }
                )
            end

            let(:other_site_due) do
                FactoryGirl.create(
                    :scan,
                    site: other_site,
                    schedule_attributes: {
                        start_at: Time.now
                    }
                )
            end

            context 'and there are available slots' do
                it 'yields them' do
                    other_site_due
                    due

                    s = []
                    subject.each_due_scan do |scan|
                        s << scan
                    end

                    expect(s).to eq [other_site_due, due]
                end
            end

            context 'and there are not enough slots left' do
                before do
                    allow(subject).to receive(:slots_free).and_return(1)
                end

                it 'yields as many as possible' do
                    other_site_due
                    due

                    s = []
                    subject.each_due_scan do |scan|
                        s << scan
                    end

                    expect(s).to eq [other_site_due]
                end
            end

            context 'and there are no slots left' do
                before do
                    allow(subject).to receive(:slots_free).and_return(0)
                end

                it 'yields nothing' do
                    other_site_due
                    due

                    s = nil
                    subject.each_due_scan do |scan|
                        s = scan
                    end

                    expect(s).to be_nil
                end
            end

            context 'and the site max parallel scans limit has been reached' do
                before do
                    due.site.max_parallel_scans = 1
                    due.site.save

                    allow(subject).to receive(:active_instance_count_for_site) { |s| s == site ? 1 : 0 }
                end

                it 'does not yield the scans for that site' do
                    other_site_due
                    due

                    s = []
                    subject.each_due_scan do |scan|
                        s << scan
                    end

                    expect(s).to eq [other_site_due]
                end
            end
        end
    end

    describe '#perform' do
        before do
            settings
        end

        it 'sets the Revision#started_at to Schedule#start_at' do
            start_at = Time.now + 1199

            scan.schedule.start_at = start_at
            scan.save

            subject.perform( scan ) rescue Arachni::Reactor::Error::NotRunning

            expect(scan.last_revision.started_at.to_i).to eq start_at.to_i
        end

        it 'sets status to initializing' do
            subject.perform( scan ) rescue Arachni::Reactor::Error::NotRunning

            expect(scan.last_revision).to be_initializing
        end

        it 'creates a new revision' do
            expect(scan.revisions.size).to be 0

            subject.perform( scan ) rescue Arachni::Reactor::Error::NotRunning

            expect(scan.revisions.size).to be 1
        end

        it 'spawns an instance' do
            expect(subject.active_instance_count).to be 0

            subject.perform( scan ) rescue Arachni::Reactor::Error::NotRunning

            expect(subject.active_instance_count).to be 1
        end

        it 'starts the scan' do
            expect_any_instance_of(MockInstanceClientService).to receive(:scan).with( scan.rpc_options )
            subject.perform( scan )
        end

        it 'sets up progress monitoring' do
            subject.start

            expect(subject).to receive(:monitor) do |revision|
                expect(revision).to eq scan.revisions.reload.first
            end
            subject.perform( scan )
            wait
            wait
        end

        context 'when the #update call yields' do
            context 'true' do
                it 'cancels the job'
            end

            context 'false' do
                it 'does not cancel the job'
            end
        end

        context 'when the scan is not recurring' do
            before do
                scan.schedule.month_frequency = nil
                scan.schedule.day_frequency = nil
                scan.schedule.save
            end

            it 'destroys the scan schedule' do
                expect(scan.schedule).to be_scheduled

                subject.perform( scan ) rescue Arachni::Reactor::Error::NotRunning

                expect(scan.reload).to_not be_scheduled
            end
        end

        context 'when the scan is recurring' do
            before do
                scan.schedule.month_frequency = 1
                scan.schedule.day_frequency = 2
                scan.schedule.save
            end

            it 'removes the scan from the schedule' do
                expect(scan.schedule).to be_scheduled

                subject.perform( scan ) rescue Arachni::Reactor::Error::NotRunning

                expect(scan.schedule).to_not be_scheduled
            end
        end

        context 'when the #scan response is an RPC exception' do
            let(:exception) { Arachni::RPC::Exceptions::Base.new }

            before do
                allow_any_instance_of(MockInstanceClientService).
                    to receive(:scan).with( scan.rpc_options ) { |&block| block.call exception }
            end

            it 'forwards it to #handle_rpc_error' do
                expect(subject).to receive(:handle_rpc_error) do |revision, e|
                    expect(revision.id).to eq scan.revisions.first.id
                    expect(e).to eq exception
                end

                subject.perform( scan )
            end

            it 'does not setup progress monitoring' do
                expect(subject).to_not receive(:monitor)

                subject.perform( scan )
                wait
            end
        end
    end

    describe '#finish' do
        it 'sets Revision#stopped_at' do
            subject.finish( revision ) {}

            expect(revision.reload.stopped_at).to be_kind_of Time
        end

        context 'when the scan is recurring' do
            before do
                scan.schedule.day_frequency = 1
                scan.schedule.month_frequency = 2
                scan.schedule.save
            end

            context 'when the scan has not been suspended' do
                it 'schedules the next run' do
                    expect(scan).to receive(:schedule_next)

                    subject.finish( revision ) {}

                    expect(scan.schedule.reload).to be_scheduled
                end
            end

            context 'when the scan has been suspended' do
                before do
                    revision.suspended!
                end

                it 'leaves it unscheduled' do
                    expect(scan).to_not receive(:schedule_next)

                    subject.finish( revision ) {}
                end
            end
        end

        context 'when the scan is not recurring' do
            before do
                scan.schedule.day_frequency = nil
                scan.schedule.month_frequency = nil
                scan.schedule.save
            end

            it 'leaves it unscheduled' do
                expect(scan).to_not receive(:schedule_next)

                subject.finish( revision ) {}
            end
        end
    end

    describe '#update' do
        before do
            instance
        end

        it 'polls for progress' do
            expect(instance).to receive(:native_progress)
            subject.update( revision ) {}
        end

        it 'includes entries' do
            expect(instance).to receive(:native_progress) do |options|
                expect(options[:with]).to include :issues
            end

            subject.update( revision ) {}
        end

        it 'excludes non-fixed scan entries' do
            fissue = Issue.create_from_engine( native_issue, revision: other_revision )
            fissue.state = 'fixed'
            fissue.save

            issue = Issue.create_from_engine( native_issue, revision: other_revision )
            issue.save

            expect(instance).to receive(:native_progress) do |options|
                expect(options[:without][:issues]).to eq [issue.digest]
            end

            subject.update( revision ) {}
        end

        it 'includes errors' do
            expect(instance).to receive(:native_progress) do |options|
                expect(options[:with]).to include :errors
            end

            subject.update( revision ) {}
        end

        it 'includes sitemap entries' do
            expect(instance).to receive(:native_progress) do |options|
                expect(options[:with]).to include :sitemap
            end

            subject.update( revision ) {}
        end

        it 'excludes entries from previous revisions' do
            Issue.create_from_engine( native_issue, revision: revision )

            expect(instance).to receive(:native_progress) do |options|
                expect(options[:without][:issues]).to be_any
                expect(options[:without][:issues]).to eq scan.issues.digests
            end

            subject.update( revision ) {}
        end

        it 'passes progress data to #handle_progress' do
            progress = { busy: true }

            expect(subject).to receive(:handle_progress_active).with(revision, progress)
            allow(instance).to receive(:native_progress) do |_, &block|
                block.call progress
            end

            subject.update( revision ) {}
        end

        context 'subsequent calls' do
            it 'exclude seen sitemap entries' do
                expect(instance).to receive(:native_progress) do |_, &block|
                    block.call(
                        busy:   true,
                        issues: [],
                        statistics: statistics,
                        errors: [],
                        sitemap: {
                            'http://test/'  => 200,
                            'http://test/1' => 200
                        }
                    )
                end
                subject.update( revision ) {}

                expect(instance).to receive(:native_progress) do |options|
                    expect(options[:with][:sitemap]).to eq 2
                end
                subject.update( revision ) {}
            end

            it 'exclude seen errors' do
                expect(instance).to receive(:native_progress) do |_, &block|
                    block.call(
                        busy:   true,
                        issues: [],
                        statistics: statistics,
                        sitemap: {},
                        errors: [
                            'line 1',
                            'line 2'
                        ]
                    )
                end
                subject.update( revision ) {}

                expect(instance).to receive(:native_progress) do |options|
                    expect(options[:with][:errors]).to eq 2
                end
                subject.update( revision ) {}
            end

            it 'exclude seen entries' do
                expect(instance).to receive(:native_progress) do |_, &block|
                    block.call(
                        busy:   true,
                        issues: [native_issue],
                        statistics: statistics,
                        errors: [],
                        sitemap: {}
                    )
                end
                subject.update( revision ) {}

                expect(instance).to receive(:native_progress) do |options|
                    expect(options[:without][:issues]).to include native_issue.digest
                end
                subject.update( revision ) {}
            end
        end
    end

    describe '#handle_progress' do
        before do
            instance
        end

        let(:progress) do
            {
                busy:       true,
                seed:       '8f0510034adf8e1905ed47b7e141dbf3',
                statistics: statistics,
                errors:     [],
                issues:     [],
                sitemap:    []
            }
        end

        context 'when there is no Revision#seed' do
            before do
                revision.seed = nil
                revision.save
            end

            it 'sets the #seed' do
                subject.handle_progress( revision, progress )

                expect(revision.seed).to eq progress[:seed]
            end
        end

        context 'when there is Revision#seed' do
            before do
                revision.seed = 'stuff'
                revision.save
            end

            it 'sets the #seed' do
                subject.handle_progress( revision, progress )

                expect(revision.seed).to eq 'stuff'
            end
        end

        context 'when :busy' do
            let(:progress) { super().merge( busy: true ) }

            it 'passes progress data to #handle_progress_active' do
                expect(subject).to receive(:handle_progress_active).with(revision, progress)
                subject.handle_progress( revision, progress )
            end
        end

        context 'when not :busy' do
            let(:progress) { super().merge( busy: false ) }

            it 'passes progress data to #handle_progress_inactive' do
                expect(subject).to receive(:handle_progress_inactive).with(revision, progress)
                subject.handle_progress( revision, progress )
            end
        end

        context 'when passed an RPC exception' do
            let(:exception) { Arachni::RPC::Exceptions::Base.new }

            it 'forwards it to #handle_rpc_error' do
                expect(subject).to receive(:handle_rpc_error).with( revision, exception )
                subject.handle_progress( revision, exception )
            end
        end
    end

    describe '#handle_progress_active' do
        before do
            instance
        end

        let(:progress) do
            {
                busy:       true,
                issues:     [],
                status:     'stuff',
                statistics: statistics,
                errors:     [],
                sitemap:    []
            }
        end

        it 'forwards the statistics to #capture_performance_snapshot' do
            expect(subject).to receive(:capture_performance_snapshot).with( revision, statistics )
            subject.handle_progress_active( revision, progress ) {}
        end

        context 'with :errors' do
            let(:progress) do
                super().merge(
                    errors: [
                        'line 1',
                        'line 2'
                    ]
                )
            end

            it 'updates them' do
                revision.error_messages = "Stuff\n"

                subject.handle_progress_active( revision, progress ) {}

                expect(revision.error_messages).to eq "Stuff\nline 1\nline 2\n"
            end
        end

        context 'with :sitemap entries' do
            let(:progress) do
                super().merge(
                    sitemap: {
                        'http://test.com/1' => 200,
                        'http://test.com/2' => 404
                    }
                )
            end

            it 'creates them' do
                expect(subject).to receive(:add_coverage_entries).with(
                    revision, progress[:sitemap]
                )

                subject.handle_progress_active( revision, progress ) {}
            end
        end

        it 'updates scan state' do
            subject.handle_progress_active( revision, progress ) {}
            expect(revision.status).to eq 'stuff'
        end

        context 'with :entries' do
            let(:progress) do
                super().merge( issues: [native_issue] )
            end

            it 'creates them' do
                expect(subject).to receive(:create_issue).with(
                    revision, native_issue
                 )

                subject.handle_progress_active( revision, progress ) {}
            end
        end

        context 'when Schedule#stop_after_hours is set' do
            before do
                scan.schedule.stop_after_hours = 1
                scan.schedule.save
            end

            context 'and the runtime has exceeded it' do
                it 'aborts the scan' do
                    expect(subject).to receive(:abort).with(revision)
                    subject.handle_progress_active( revision, progress ) {}
                end

                it 'sets Scan#timed_out' do
                    expect(subject).to receive(:abort).with(revision)
                    subject.handle_progress_active( revision, progress ) {}
                    expect(revision).to be_timed_out
                end

                context 'and Schedule#stop_suspend is set' do
                    before do
                        scan.schedule.stop_suspend = true
                        scan.schedule.save
                    end

                    it 'suspends the scan' do
                        expect(subject).to receive(:suspend).with(revision)
                        subject.handle_progress_active( revision, progress ) {}
                    end

                    context 'and #suspend has already been called' do
                        it 'does nothing' do
                            subject.suspend revision

                            expect(subject).to_not receive(:suspend).with(revision)
                            subject.handle_progress_active( revision, progress ) {}
                        end
                    end
                end
            end
        end
    end

    describe '#handle_progress_inactive' do
        before do
            instance

            allow(subject).to receive(:stop_monitor)
            allow(subject).to receive(:download_report_and_shutdown)
        end

        let(:progress) do
            {
                busy:   false,
                errors: []
            }
        end

        it 'stops monitoring' do
            expect(subject).to receive(:stop_monitor).with( revision )
            subject.handle_progress_inactive( revision, progress ) {}
        end

        context 'with :errors' do
            let(:progress) do
                super().merge(
                    errors: [
                        'line 1',
                        'line 2'
                    ]
                )
            end

            it 'updates them' do
                revision.error_messages = "Stuff\n"

                subject.handle_progress_inactive( revision, progress ) {}

                expect(revision.error_messages).to eq "Stuff\nline 1\nline 2\n"
            end
        end

        context 'when the scan has not been suspended' do
            it 'calls #download_report_and_shutdown' do
                expect(subject).to receive(:download_report_and_shutdown).with(
                   revision, mark_issues_fixed: true, status: 'completed'
                )

                subject.handle_progress_inactive( revision, progress ) {}
            end

            context 'when the revision was a result of a rescope' do
                let(:args) { [revision.next, mark_issues_fixed: false, status: 'completed'] }

                it 'calls does not mark entries fixed' do
                    subject.rescope( revision )

                    r = revision.next

                    expect(subject).to receive(:download_report_and_shutdown).with(
                        r, mark_issues_fixed: false, status: 'completed'
                    )

                    subject.handle_progress_inactive( r, progress ) {}
                end
            end
        end

        context 'when the scan has been suspended' do
            let(:progress) do
                super().merge(
                    status: :suspended
                )
            end

            it 'sets scan status to suspended' do
                subject.handle_progress_inactive( revision, progress ) {}

                expect(revision).to be_suspended
            end

            it 'sets #snapshot_path' do
                subject.handle_progress_inactive( revision, progress ) {}

                expect(revision.snapshot_path).to eq '/my/path'
            end
        end
    end

    describe '#capture_performance_snapshot' do
        it 'updates the current performance snapshot' do
            expect(revision.performance_snapshot).to receive(:update).
                                                         with( performance_snapshot_attributes )

            subject.capture_performance_snapshot( revision, statistics )
        end

        context 'the first time it is called' do
            it 'stores the performance snapshot' do
                expect(revision.performance_snapshots).to receive(:create).
                                                             with( performance_snapshot_attributes )

                subject.capture_performance_snapshot( revision, statistics )
            end
        end

        context 'when more than PERFORMANCE_SNAPSHOT_CAPTURE_INTERVAL seconds have passed since the last call' do
            it 'stores the performance snapshot' do
                described_class::PERFORMANCE_SNAPSHOT_CAPTURE_INTERVAL = 2.seconds

                subject.capture_performance_snapshot( revision, statistics )

                sleep described_class::PERFORMANCE_SNAPSHOT_CAPTURE_INTERVAL

                expect(revision.performance_snapshots).to receive(:create).
                                                                  with( performance_snapshot_attributes )

                subject.capture_performance_snapshot( revision, statistics )
            end
        end

        context 'when less than PERFORMANCE_SNAPSHOT_CAPTURE_INTERVAL seconds has passed since the last call' do
            it 'does not store the performance snapshot' do
                subject.capture_performance_snapshot( revision, statistics )

                expect(revision.performance_snapshots).to_not receive(:create).
                                                              with( performance_snapshot_attributes )

                subject.capture_performance_snapshot( revision, statistics )
            end
        end
    end

    describe '#download_report_and_shutdown' do
        let(:report) do
            report = Factory[:report]
            report.options[:url] = 'http://test.com'
            report.sitemap = {
                report.options[:url] => 200
            }
            report
        end

        before do
            expect(instance).to receive(:native_abort_and_report) do |_, &block|
                block.call report
            end
        end

        it 'retrieves the report' do
            subject.download_report_and_shutdown(revision)
        end

        it 'calls #finish' do
            expect(subject).to receive(:finish).with( revision )

            subject.download_report_and_shutdown(revision)
        end


        it "stores the report under #{described_class}::REPORT_DIR" do
            subject.download_report_and_shutdown(revision)

            expect(File.exist?(described_class::REPORT_DIR + "/#{revision.id}.afr")).to be_truthy
        end

        it 'passes the report to #import_issues_from_report' do
            expect(subject).to receive(:import_issues_from_report).
                                   with( revision, report )

            subject.download_report_and_shutdown(revision)
        end

        it 'passes the report to #import_coverage_from_report' do
            expect(subject).to receive(:import_coverage_from_report).
                                   with( revision, report )

            subject.download_report_and_shutdown(revision)
        end

        it 'calls #kill_instance_for' do
            expect(subject).to receive(:kill_instance_for).with(revision)
            subject.download_report_and_shutdown(revision)
        end

        context 'when :status is given' do
            it 'sets it' do
                subject.download_report_and_shutdown( revision, status: 'completed' )
                expect(revision).to be_completed
            end
        end

        context 'when :status is not given' do
            it 'does not affect the status' do
                revision.paused!
                subject.download_report_and_shutdown( revision )
                expect(revision).to be_paused
            end
        end

        context 'when :mark_issues_fixed is' do
            context 'true' do
                context 'and the scan has more than 1 revision' do
                    before do
                        new_revision
                    end

                    it 'passes the report issue digests to #mark_other_issues_fixed' do
                        expect(subject).to receive(:mark_other_issues_fixed).
                                               with( revision, report.issues.map(&:digest) )

                        subject.download_report_and_shutdown( revision, mark_issues_fixed: true )
                    end
                end

                context 'and has 1 revision' do
                    it 'does not call #mark_other_issues_fixed' do
                        expect(subject).to_not receive(:mark_other_issues_fixed)

                        subject.download_report_and_shutdown(revision)
                    end
                end
            end

            context 'false' do
                context 'and has 1 revision' do
                    it 'does not call #mark_other_issues_fixed' do
                        expect(subject).to_not receive(:mark_other_issues_fixed)

                        subject.download_report_and_shutdown( revision, mark_issues_fixed: true )
                    end
                end
            end
        end
    end

    describe '#import_coverage_from_report' do
        let(:report) do
            report = Factory[:report]
            report.options[:url] = 'http://test.com'
            report.sitemap = {
                report.options[:url] => 404
            }
            report
        end

        it 'forwards its sitemap to #add_coverage_entries' do
            expect(subject).to receive(:add_coverage_entries).with( revision, report.sitemap )
            subject.import_coverage_from_report( revision, report )
        end
    end

    describe '#add_coverage_entries' do
        before do
            revision.sitemap_entries = []
            revision.save
        end

        let(:sitemap) do
            {
                'http://test.com/1' => 200,
                'http://test.com/2' => 404
            }
        end

        context 'when a URL has already been logged' do
            it 'updates it' do
                revision.sitemap_entries.create( url: 'http://test.com/2', code: 200 )

                subject.add_coverage_entries( revision, sitemap )

                revision.sitemap_entries.reload

                expect(revision.sitemap_entries.size).to eq 2

                entries = revision.sitemap_entries

                entry = entries[0]
                expect(entry.url).to eq 'http://test.com/1'
                expect(entry.code).to eq 200
                expect(entry).to be_coverage

                entry = entries[1]
                expect(entry.url).to eq 'http://test.com/2'
                expect(entry.code).to eq 404
                expect(entry).to be_coverage
            end
        end

        context 'when a URL has not already been logged' do
            it 'creates it' do
                subject.add_coverage_entries( revision, sitemap )

                revision.sitemap_entries.reload

                expect(revision.sitemap_entries.size).to eq 2

                entries = revision.sitemap_entries

                entry = entries[0]
                expect(entry.url).to eq 'http://test.com/1'
                expect(entry.code).to eq 200
                expect(entry).to be_coverage

                entry = entries[1]
                expect(entry.url).to eq 'http://test.com/2'
                expect(entry.code).to eq 404
                expect(entry).to be_coverage
            end
        end
    end

end
