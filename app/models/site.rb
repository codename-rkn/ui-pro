class Site < ActiveRecord::Base
    include WithEvents

    PROTOCOL_TYPES = %w(http https)
    FAVICONS_DIR   = "#{Rails.root}/public/site_favicons/"

    events track: %w(max_parallel_scans)
    children_events do
        {
            Schedule => scans.select(:id)
        }
    end

    enum protocol: [ :http, :https ]

    belongs_to :user, optional: true
    has_and_belongs_to_many :users

    has_one :profile, autosave: true, dependent: :destroy,
            foreign_key: 'site_id', class_name: 'SiteProfile'
    accepts_nested_attributes_for :profile, update_only: true

    has_many :scans, dependent: :destroy
    has_many :schedules, through: :scans
    has_many :revisions, dependent: :destroy
    has_many :entries, dependent: :destroy
    has_many :reviewed_entries, through: :scans

    has_many :roles, dependent: :destroy, foreign_key: 'site_id',
             class_name: 'SiteRole'

    has_many :sitemap_entries, dependent: :destroy

    validates_presence_of :protocol

    validates_presence_of   :host
    validates_uniqueness_of :host, scope: [:user_id, :port, :protocol]

    validates_presence_of     :port
    validates_numericality_of :port, greater_than: 0

    after_create :create_guest_role
    before_save  :ensure_profile

    # Broadcasts callbacks.
    after_create_commit :broadcast_create_job
    after_destroy_commit :broadcast_destroy_job

    def url
        u = "#{protocol}://#{host}"

        if (protocol == 'http' && port == 80) ||
            (protocol == 'https' && port == 443)
            return u
        end

        "#{u}:#{port}"
    end
    alias :to_s :url

    def scanned_or_being_scanned?
        revisions.where.not( started_at: nil ).any?
    end

    def being_scanned?
        revisions.in_progress?
    end

    def destroying!
        self.processing = 'destroying'
        self.save
    end

    def destroying?
        self.processing == 'destroying'
    end

    def revision_in_progress
        return if revisions.size == 0
        revisions.includes(:scan).in_progress.first
    end

    def scanned?
        revisions.size > 0
    end

    def last_scanned_at
        revisions.last_performed_at
    end

    def last_revision
        # revisions.includes(scan: [:schedule, :device, :site_role, :profile]).order( id: :desc ).first
        revisions.order( id: :desc ).first
    end

    def https?
        protocol == 'https'
    end

    def favicon_path
        return if !has_favicon?
        provisioned_favicon_path
    end

    def favicon
        return if !has_favicon?
        provisioned_favicon
    end

    def has_favicon?
        File.exist? provisioned_favicon_path
    end

    def provisioned_favicon_path
        "#{FAVICONS_DIR}/#{provisioned_favicon}"
    end

    def provisioned_favicon
        "#{host}_#{port}.ico"
    end

    private

    def ensure_profile
        self.profile ||= build_profile(
            SiteProfile.flatten( SCNR::Engine::Options.to_rpc_data )
        )
    end

    def create_guest_role
        self.roles.create(
            name:        'Guest',
            description: 'Un-authenticated visitor.',
            login_type:  'none'
        )
    end

    def broadcast_create_job
        Broadcasts::Sites::CreateJob.perform_later(id)
    end

    def broadcast_destroy_job
        Broadcasts::Sites::DestroyJob.perform_later(id, user_id)
    end

end
