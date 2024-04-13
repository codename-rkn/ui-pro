class ScanScheduler
    include Singleton

    # Interval (in seconds) for checking for due scans and progress monitoring.
    TICK = 5

    class Error < RuntimeError
        class AlreadyRunning < Error
        end
    end

    Dir.glob( "#{File.dirname( __FILE__ )}/scan_scheduler/helpers/*.rb" ).
        each { |f| require f }

    include Helpers::ErrorHandling
    include Helpers::Instance
    include Helpers::Entry
    include Helpers::Logging
    include Helpers::Scan
    include Helpers::Slots

    def initialize
        super

        reactor.run_in_thread

        reactor.on_error do |_, e|
            ap "[#{e.class}] #{e}"
            ap e.backtrace
            log_exception( e )
        end

        @task  = nil
        @ticks = 0

        @after_next_tick_blocks = []
    end

    def after_next_tick( &block )
        @after_next_tick_blocks << block
    end

    # Starts the scan scheduler.
    #
    # Will begin checking the {Schedule}s for {Schedule.due} scans every {TICK}
    # seconds and {#perform} them, so long as there are available slots.
    def start
        fail Error::AlreadyRunning, 'Already running.' if running?

        reactor.at_interval TICK do |task|
            @task   = task
            @ticks += 1

            log_info 'Tick'

            each_due_scan do |scan|
                perform scan
            end

            @after_next_tick_blocks.each { |b| b.call @ticks }
            @after_next_tick_blocks.clear
        end
    end

    # Stops the periodic check for {Schedule.due} scans scans.
    def stop
        return if !running?

        @task.done
        @task = nil
    end

    # @return   [Boolean]
    #   `true` if the scheduler is running, `false` otherwise.
    def running?
        !!@task
    end

    # @return   [Raktr]
    def reactor
        @reactor ||= Raktr.new
    end

    def reset
        reset_entry_state
        reset_scan_state
        reset_instance_state
    end

    class <<self
        def method_missing( sym, *args, &block )
            if instance.respond_to?( sym )
                instance.send( sym, *args, &block )
            else
                super( sym, *args, &block )
            end
        end

        def respond_to?( *args )
            super || instance.respond_to?( *args )
        end
    end
end
