class Profile < ActiveRecord::Base
    include WithCustomSerializer
    include WithEvents
    include WithScannerOptions
    include ProfileImport
    include ProfileExport
    include ProfileDefaultHelpers

    events
    set_scanner_options(
        checks:     { type: Array,  validate: true },
        plugins:    { type: Hash,   validate: true },

        audit_links:                :bool,
        audit_forms:                :bool,
        audit_cookies:              :bool,
        audit_cookies_extensively:  :bool,
        audit_headers:              :bool,
        audit_jsons:                :bool,
        audit_xmls:                 :bool,
        audit_ui_forms:             :bool,
        audit_ui_inputs:            :bool,
        audit_parameter_names:      :bool,

        audit_with_extra_parameter:     :bool,
        audit_with_both_http_methods:   :bool,
        audit_exclude_vector_patterns:  { type: Array, validate: :patterns, format: :lsv },
        audit_include_vector_patterns:  { type: Array, validate: :patterns, format: :lsv },

        scope_depth_limit:              Integer,
        scope_dom_depth_limit:          Integer,
        scope_directory_depth_limit:    Integer,
        scope_page_limit:               Integer,

        scope_exclude_binaries:         :bool,
        # scope_restrict_paths:           { type: Array, format: :lsv },
        scope_exclude_content_patterns: { type: Array, validate: :patterns, format: :lsv },
        scope_exclude_path_patterns:    { type: Array, validate: :patterns, format: :lsv },
        scope_include_path_patterns:    { type: Array, validate: :patterns, format: :lsv },
    )

    belongs_to :user
    has_many   :scans, -> { order id: :desc }
    has_many   :revisions, through: :scans

    validates_presence_of   :description
    validate :validate_description

    validates_presence_of   :name
    validates_uniqueness_of :name, scope: :user

    # Broadcasts callbacks.
    after_create_commit :broadcast_create_job
    after_update_commit :broadcast_update_job
    after_destroy_commit :broadcast_destroy_job

    def to_s
        name
    end

    def checks_with_info
        checks.inject({}) { |h, n| h[n] = ::FrameworkHelper.checks[n]; h }
    end

    def plugins_with_info
        plugins.keys.inject({}) { |h, n| h[n] = ::FrameworkHelper.plugins[n]; h }
    end

    private

    def validate_description
        return if ActionController::Base.helpers.strip_tags( description ) == description
        errors.add :description, 'cannot contain HTML, please use Markdown instead'
    end

    def validate_checks
        available = ::FrameworkHelper.checks.keys.map( &:to_s )
        checks.each do |check|
            next if available.include? check.to_s
            errors.add :checks, "'#{check}' does not exist"
        end
    end

    def validate_platforms
        available = ::FrameworkHelper.platform_shortnames.map(&:to_s)
        platforms.each do |platform|
            next if available.include? platform.to_s
            errors.add :platforms, "'#{platform}' does not exist"
        end
    end

    def validate_plugins
        available = ::FrameworkHelper.plugins.keys.map( &:to_s )
        plugins.keys.each do |plugin|
            next if available.include? plugin.to_s
            errors.add :plugins, "'#{plugin}' does not exist"
        end
    end

    def validate_plugin_options
        available = ::FrameworkHelper.plugins.keys.map( &:to_s )
        ::FrameworkHelper.framework do |f|
            plugins.each do |plugin, options|
                next if !available.include? plugin.to_s

                begin
                    f.plugins.prepare_options(
                        plugin, f.plugins[plugin],
                        (options || {}).reject { |k, v| v.empty? }
                    )
                rescue SCNR::Engine::Component::Options::Error::Invalid => e
                    errors.add :plugins, e.to_s
                end
            end
        end
    end

    private

    def broadcast_create_job
        Broadcasts::Profiles::CreateJob.perform_later(id)
    end

    def broadcast_update_job
        Broadcasts::Profiles::UpdateJob.perform_later(id)
    end

    def broadcast_destroy_job
        Broadcasts::Profiles::DestroyJob.perform_later(id, user_id)
    end

end
