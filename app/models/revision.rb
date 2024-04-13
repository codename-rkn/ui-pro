class Revision < ActiveRecord::Base
    include WithCustomSerializer
    include WithEvents
    include RevisionStates

    events track: %w(status timed_out)

    custom_serialize :rpc_options, Hash

    has_one  :report, dependent: :destroy

    has_one  :performance_snapshot, dependent: :destroy,
             foreign_key: 'revision_current_id'

    belongs_to :scan, counter_cache: true, optional: true
    belongs_to :site, counter_cache: true, optional: true

    # Copies of site settings and role at the time the revision was created.
    # These can change over time so keep a frozen copy.
    has_one :site_profile, dependent: :destroy
    has_one :site_role, dependent: :destroy

    has_many :entries,  dependent: :destroy
    has_and_belongs_to_many :missing_entries, class_name: 'Entry',
                            join_table: 'missing_entries_revisions'
    has_many :reviewed_entries,  class_name: 'Entry',
             foreign_key: 'reviewed_by_revision_id'

    has_many :sitemap_entries, dependent: :destroy

    has_many :performance_snapshots, -> { order id: :asc }, dependent: :destroy

    validates_presence_of :scan

    before_create :ensure_performance_snapshot

    before_validation :set_site

    before_save :set_index
    before_save :set_rpc_options
    before_save :copy_site_profile
    before_save :copy_site_role

    scope :in_progress, -> do
        where.not( started_at: nil ).where( stopped_at: nil )
    end

    def self.last_performed
        where.not( stopped_at: nil ).order( stopped_at: :desc ).limit(1).first
    end

    def self.last_performed_at
        where.not( stopped_at: nil ).order( stopped_at: :desc ).limit(1).
            pluck(:stopped_at).first
    end

    def self.in_progress?
        in_progress.any?
    end

    def previous
        scan.revisions.where( index: index - 1 ).first
    end

    def next
        scan.revisions.where( index: index + 1 ).first
    end

    def duration
        return if !started_at

        (stopped_at || Time.zone.now) - started_at
    end

    def stopped?
        !!stopped_at
    end

    def performed_at
        stopped_at
    end

    def in_progress?
        started_at && !stopped_at
    end

    def to_s
        "#{index.ordinalize} revision"
    end

    private

    def copy_site_profile
        return if self.site_profile

        dupped = site.profile.dup
        # Associations will get confused, revision has a #site anyways.
        dupped.site = nil

        self.site_profile = dupped
    end

    def copy_site_role
        return if self.site_role

        dupped = scan.site_role.dup
        # Associations will get confused, revision has a #site anyways.
        dupped.site = nil

        self.site_role = dupped
    end

    def set_rpc_options
        return if self.rpc_options.any?
        self.rpc_options = scan.rpc_options
    end

    def set_index
        self.index ||= scan.revisions.count + 1
    end

    def set_site
        self.site ||= scan.site
    end

    def ensure_performance_snapshot
        self.performance_snapshot ||= build_performance_snapshot
    end

end
