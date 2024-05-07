class ScanScheduler
module Helpers
module Scan

    # Location for storing SEP reports.
    #
    # Names will be in the format of `<Revision#id>.afr`.
    REPORT_DIR = "#{Rails.root}/reports/"

    PERFORMANCE_SNAPSHOT_CAPTURE_INTERVAL = 1.minute

    def initialize
        super

        reset_scan_state
    end

    # Pauses the scan for the given `revision`.
    #
    # @param    [Revision]  revision
    def pause( revision )
        log_info_for revision, 'Pausing'

        instance_for( revision ).pause! do |r|
            log_info_for revision, 'Paused'

            handle_if_rpc_error( revision, r )
        end

        broadcast_to_the_channels( revision )
    end

    # Resumes the scan for the given `revision`.
    #
    # @param    [Revision]  revision
    def resume( revision )
        log_info_for revision, 'Resuming'

        instance_for( revision ).resume! do |r|
            log_info_for revision, 'Resumed'

            handle_if_rpc_error( revision, r )
        end

        broadcast_to_the_channels( revision )
    end

    # Resumes the scan for the given `revision`.
    #
    # @param    [Revision]  revision
    def restore( revision )
        log_info_for revision, 'Restoring'

        revision.restoring!
        revision.timed_out = false
        revision.save

        revision.update(
            started_at: Time.now,
            stopped_at: nil
        )

        spawn_instance_for( revision ) do |instance|
            instance.restore!( revision.snapshot_path ) do |r|
                log_info_for revision, 'Restoring'

                next if handle_if_rpc_error( revision, r )

                monitor( revision )
            end
        end

        broadcast_to_the_channels( revision )
    end

    # Suspends the scan for the given `revision`.
    #
    # @param    [Revision]  revision
    def suspend( revision )
        log_info_for revision, 'Suspending'

        suspending revision

        instance = instance_for( revision )

        instance.suspend! do |r|
            log_info_for revision, 'Suspended, grabbing snapshot path.'
            handle_if_rpc_error( revision, r )
        end

        broadcast_to_the_channels( revision )
    end

    # Aborts the scan for the given `revision`.
    #
    # @param    [Revision]  revision
    def abort( revision )
        log_info_for revision, 'Aborting'

        stop_monitor( revision )

        revision.aborting!

        download_report_and_shutdown( revision, status: 'aborted' )

        broadcast_to_the_channels( revision )
    end

    def each_due_scan( &block )
        # Check for due scans first, THEN for free slots.
        # The free slots check will use a lot of CPU and we can't run it for
        # every tick.
        due = Schedule.includes( scan: :site ).due
        return if due.empty?

        slots = self.slots_free

        # Don't even bother...
        if slots <= 0
            log_info 'No available slots.'
            return
        end

        # Don't use #limit here to only grab the amount of scans for available
        # slots, because we may introduce a bottleneck.
        #
        # If we have a global limit of 5 and a site with a limit of 1 and
        # the site has 10 consecutive scans scheduled, then we'll be grabbing
        # the first 5 scans and just skipping them due to the site limit.
        #
        # This will block scans for other sites which could be run, until the
        # previous site's scans are performed, one at a time -- which is stupid.
        due.each do |schedule|
            scan = schedule.scan
            log_info "Scan due: #{scan} (#{scan.id})"

            if slots <= 0
                log_info ' -- No available slots.'
                return
            end

            site = scan.site
            if site.profile.max_parallel_scans <= active_instance_count_for_site( site )
                log_info ' -- Site limit has been reached.'
                next
            end

            begin
                block.call scan
            ensure
                slots -= 1
            end
        end
    end

    # Performs the scan.
    #
    # Will remove the `scan` from the {Schedule.due schedule}, create a new
    # revision, spawn an instance, start the scan and add monitoring for its
    # progress.
    #
    # @param    [Scan]  scan
    def perform( scan )
        log_info "Performing: #{scan}"

        start_at = scan.schedule.start_at

        # Remove this scan from the schedule list.
        scan.schedule.unschedule

        revision = scan.revisions.create(
            # We don't use Time.now because it will lead to small slips
            # over time.
            started_at: start_at
        )
        revision.initializing!

        log_info_for revision, 'Created revision.'

        spawn_instance_for( revision ) do |instance|
            instance.run( revision.rpc_options ) do |response|
                next if handle_if_rpc_error( revision, response )

                monitor( revision )
            end
        end

        broadcast_to_the_channels( revision )
    end

    def rescope( revision )
        scan     = revision.scan
        instance = instance_for( revision )

        log_info "Rescoping: #{scan}"

        now = Time.now
        started_at = revision.started_at

        stop_monitor( revision )
        revision.update(
            status:     'rescoped',
            stopped_at: now
        )

        instance_url = @revision_id_to_instance_url.delete( revision.id )

        # Use the previous revision's start time
        revision = scan.revisions.create(
            started_at: started_at
        )
        revision.initializing!

        log_info_for revision, 'Created revision.'

        @revision_id_to_instance_url[revision.id] = instance_url

        instance.options.set( revision.rpc_options ) do |response|
            next if handle_if_rpc_error( revision, response )

            monitor( revision )
        end

        broadcast_to_the_channels( revision )
    end

    def monitor( revision )
        reactor.at_interval TICK do |task|
            @monitors[revision.id] = task
            update( revision )
        end
    end

    def stop_monitor( revision )
        return if !@monitors[revision.id]

        @monitors.delete( revision.id ).done
    end

    # Polls the `revision` for progress and updates its data.
    #
    # @param    [Revision]  revision
    def update( revision )
        instance = instance_for( revision )

        log_info_for revision, 'Checking progress.'

        progress_tracking_for( revision )[:entry_digests] ||= revision.scan.entries.digests

        # With errors and summary sitemap.
        instance.scan.progress(
            with:    {
                sitemap: progress_tracking_for( revision )[:coverage_entries].size,
                errors:  progress_tracking_for( revision )[:error_lines]
            },
            without: { entries: progress_tracking_for( revision )[:entry_digests] },
        ) do |progress|
            handle_progress( revision, progress )
        end
    end

    def handle_progress( revision, progress )
        if progress.rpc_exception?
            handle_rpc_error( revision, progress )
            return
        end

        progress = progress.my_symbolize_keys

        log_info_for revision, 'Got progress.'

        # ap progress
        # ap progress[:busy]
        # ap progress[:status]
        # ap progress[:statistics]
        # ap progress[:messages]
        # ap progress[:sitemap]

        log_debug_for revision, "Running: #{progress[:running]}"
        log_debug_for revision, "Status:  #{progress[:status]}"

        if !revision.seed
            revision.update( seed: progress[:seed] )
        end

        if progress[:running]
            handle_progress_active( revision, progress )
        else
            handle_progress_inactive( revision, progress )
        end
    end

    def handle_progress_active( revision, progress )
        schedule   = revision.scan.schedule
        statistics = progress[:statistics]
        runtime    = statistics[:runtime]

        if !suspending?( revision ) && schedule.stop_after_hours &&
            schedule.stop_after_hours.hours < runtime.seconds

            log_debug_for revision, 'Timeout reached.'
            # ap 'TIMEOUT'

            revision.timed_out = true
            revision.save

            if schedule.stop_suspend
                suspend revision
            else
                abort revision
            end

            broadcast_to_the_channels( revision )

            return
        end

        log_debug_for revision, "Entries: #{progress[:entries].size}"

        progress_tracking_for( revision )[:entry_digests] ||= []
        progress[:entries].each do |digest, entry|
            progress_tracking_for( revision )[:entry_digests] << digest
            create_entry( revision, entry )
        end

        add_coverage_entries( revision, progress[:sitemap] )

        capture_performance_snapshot( revision, statistics )

        progress_tracking_for( revision )[:error_lines] += progress[:errors].size

        update = {}
        if revision.status != progress[:status].to_s
            update[:status] = progress[:status]
        end

        # Add a newline at the end if we have any errors.
        if progress[:errors].any?
            update[:error_messages] = "#{revision.error_messages}#{progress[:errors].join( "\n" )}\n"
        end

        broadcast_to_the_channels( revision )

        return if update.empty?

        revision.update( update )

    rescue => e
        ap e.to_s
        ap e.backtrace
    end

    def handle_progress_inactive( revision, progress )
        instance = instance_for( revision )

        stop_monitor( revision )

        if progress[:errors].any?
            revision.error_messages = "#{revision.error_messages}#{progress[:errors].join( "\n" )}\n"
        end

        # Special case...
        if progress[:status] == 'suspended'
            instance.snapshot_path do |path|
                next if handle_if_rpc_error( revision, path )

                log_info_for revision, "Suspended, got snapshot path: #{path}"

                revision.update(
                    status:        'suspended',
                    snapshot_path: path
                )

                finish( revision )
            end
        else
            download_report_and_shutdown( revision, status: 'completed' )
        end
    end

    def finish( revision )
        done_suspending( revision )
        @progress_tracker.delete revision.id

        scan = revision.scan

        revision.update( stopped_at: Time.now )

        # This one's done, schedule the next one if it's recurring.
        if !revision.suspended? && scan.recurring?
            scan.schedule_next

            log_info_for revision, 'Scheduled next occurrence for: ' +
                scan.schedule.start_at.to_s
        end

        kill_instance_for( revision )

        broadcast_to_the_channels( revision )
    end

    def broadcast_to_the_channels( revision )
        return if revision.blank?

        scan        = revision.scan
        site        = revision.site
        user        = site.try(:user)
        profile     = site.try(:profile)
        device      = site.try(:device)
        site_role   = scan.try(:scan_role)

        Broadcasts::Sites::UpdateJob.perform_later(site.id)             if site.present?
        Broadcasts::Devices::UpdateJob.perform_later(device.id)         if device.present?
        Broadcasts::Profiles::UpdateJob.perform_later(profile.id)       if profile.present?
        Broadcasts::SiteRoles::UpdateJob.perform_later(site_role.id)    if site_role.present?
        Broadcasts::Scans::UpdateJob.perform_later(scan.id)             if scan.present?
        Broadcasts::ScanResults::UpdateJob.perform_later(user.id)       if user.present?

        true
    end

    def download_report_and_shutdown( revision, status: nil )
        log_info_for revision, 'Grabbing report'

        instance = instance_for( revision )
        instance.generate_report do |report|
            report = report.data

            log_info_for revision, 'Got report'

            begin
                import_entries_from_report( revision, report )
                mark_missing_entries_from_report( revision, report )

                revision.report = Report.create( data: report.to_json )
                revision.save

            rescue => e
                log_exception_for( revision, e )
            end

            finish( revision )

            if status && revision.status != status
                revision.status = status
                revision.save

                log_info_for revision, status.capitalize
            end

            broadcast_to_the_channels( revision )
        end
    end

    def mark_missing_entries_from_report( revision, report )
        revision.scan.entries.reorder('').where.not(
          digest: report['entries'].map { |entry| entry['digest'] }
        ).each do |entry|
            revision.missing_entries << entry
        end
    end

    def add_coverage_entries( revision, sitemap )
        sitemap.each do |url, code|
            add_coverage_entry( revision, url, code )
        end
    end

    def add_coverage_entry( revision, url, code )
        return if progress_tracking_for( revision )[:coverage_entries].include?( url )
        progress_tracking_for( revision )[:coverage_entries] << url

        entry = revision.sitemap_entries.find_or_initialize_by( url: url )
        entry.update( coverage: true, code: code ) if !entry.coverage
    end

    def done_suspending( revision )
        @suspending.delete revision.id
    end

    def suspending( revision )
        @suspending << revision.id
    end

    def suspending?( revision )
        @suspending.include?( revision.id )
    end

    def capture_performance_snapshot( revision, statistics )
        progress_tracking_for( revision )[:last_performance_update] ||=
            PERFORMANCE_SNAPSHOT_CAPTURE_INTERVAL.ago

        attributes = PerformanceSnapshot.engine_to_attributes( statistics )

        revision.performance_snapshot.update( attributes )

        return if Time.now - progress_tracking_for( revision )[:last_performance_update] <
                    PERFORMANCE_SNAPSHOT_CAPTURE_INTERVAL

        revision.performance_snapshots.create( attributes )

        progress_tracking_for( revision )[:last_performance_update] = Time.now

        broadcast_to_the_channels( revision )
    end

    def progress_tracking_for( revision )
        @progress_tracker[revision.id] ||= {
            entry_digests:    nil,
            coverage_entries: [],
            sitemap:          ::Set.new,
            error_lines:      0
        }
    end

    # @private
    def reset_scan_state
        @progress_tracker = {}
        @monitors         = {}
        @suspending       = Set.new
    end

end
end
end
