class Entry < ActiveRecord::Base
    include WithEvents

    DEFAULT_STATE = 'pending'
    STATES        = %w(pending reviewed)

    events track: %w(state)

    belongs_to :revision, counter_cache: true, optional: true
    belongs_to :reviewed_by_revision, class_name: 'Revision',
               foreign_key: 'reviewed_by_revision_id', optional: true

    belongs_to :site, counter_cache: true, optional: true
    belongs_to :scan, counter_cache: true, optional: true

    has_many :siblings, class_name: 'Entry', foreign_key: :digest,
             primary_key: :digest

    belongs_to :page, class_name: 'EntryPage', foreign_key: 'entry_page_id',
               dependent: :destroy, optional: true

    belongs_to :referring_page, class_name: 'EntryPage',
               foreign_key: 'referring_entry_page_id', dependent: :destroy,
               optional: true

    belongs_to :type, class_name: 'EntryType', foreign_key: 'entry_type_id',
                optional: true

    belongs_to :sitemap_entry, counter_cache: true, optional: true

    has_one  :input_vector, dependent: :destroy
    has_many :remarks, class_name: 'EntryRemark', foreign_key: 'entry_id',
                dependent: :destroy

    has_and_belongs_to_many :platforms, class_name: 'EntryPlatform'
    has_and_belongs_to_many :sinks, class_name: 'EntrySink'

    validates :state, presence: true, inclusion: { in: STATES }

    before_save :set_owners

    STATES.each do |state|
        scope state, -> do
            where( state: state )
        end

        define_method "#{state}?" do
            self.state == state
        end
    end

    scope :reviewed,    -> { where.not reviewed_by_revision: nil }

    default_scope do
        includes(:type).includes(:input_vector).
            order( Arel.sql( 'entry_types.name asc') ).order( state_order_sql )
    end

    def has_proofs?
        remarks.any? || !proof.blank? ||
            (page && page.dom && page.dom.execution_flow_sinks &&
                page.dom.execution_flow_sinks.any?)
    end

    def reviewed_by_revision?
        !!reviewed_by_revision
    end

    def auto_reviewed?
        reviewed_by_revision?
    end

    def auto_review_status
        return if !auto_reviewed?

        case state
            when 'trusted', 'untrusted'
                'regression'
            else
                state
        end
    end

    def to_s
        s = ''

        if type
            s << type.name
        end

        if input_vector
            s << " in #{input_vector}"

            if input_vector.affected_input_name
                s << " input '#{input_vector.affected_input_name}'"
            end
        end

        s
    end

    def revision=( rev )
        self.scan = rev.scan
        self.site = rev.site
        super rev
    end

    def self.digests
        pluck(:digest).uniq
    end

    def self.count_states
        # We need to remove the order since we're counting fields that are
        # used for ordering and PG will go ape.
        counted_states = reorder('').group( 'entries.state' ).count

        states = {}
        Entry::STATES.each do |state|
            states[state.to_s] = counted_states[state.to_s]
            states[state.to_s] ||= 0
        end

        states
    end

    def self.count_input_vector_kinds
        # We need to remove the order since we're counting fields that are
        # used for ordering and PG will go ape.
        reorder('').joins(:input_vector).group( 'input_vectors.kind' ).count
    end

    def self.count_platforms
        # We need to remove the order since we're counting fields that are
        # used for ordering and PG will go ape.
        reorder('').joins(:platforms).group( 'entry_platforms.name' ).count
    end

    def self.count_sinks
        # We need to remove the order since we're counting fields that are
        # used for ordering and PG will go ape.
        reorder('').joins(:sinks).group( 'entry_sinks.name' ).count
    end

    def self.state_order_sql
        ret = 'CASE'
        STATES.each_with_index do |p, i|
            ret << " WHEN entries.state = '#{p}' THEN #{i}"
        end
        ret << ' END'

        Arel.sql( ret )
    end

    def self.unique_revisions
        Revision.where(
            id: select( 'entries.revision_id' ).pluck( 'entries.revision_id' ).uniq
        )
    end

    def self.create_from_engine( entry, options = {} )
        entry = entry.my_symbolize_keys

        entry_remarks = []
        entry[:remarks].each do |author, remarks|
            remarks.each do |remark|
                entry_remarks << EntryRemark.create( author: author, text: remark )
            end
        end

        platforms = []
        entry[:platforms].each do |platform|
            platforms << EntryPlatform.find_by_shortname( platform.to_s )
        end

        sinks = []
        entry[:sinks].stringify_keys[entry[:mutation][:affected_input_name]].each do |sink|
            sinks << EntrySink.find_by_name( sink.to_s )
        end

        entry = create({
            digest:         entry[:digest],
            page:           EntryPage.create_from_engine( entry[:page] ),
            referring_page: EntryPage.create_from_engine( entry[:mutation][:page] ),
            input_vector:   InputVector.create_from_engine( entry[:mutation] ),
            remarks:        entry_remarks,
            platforms:      platforms,
            sinks:          sinks,
            state:          DEFAULT_STATE
       }.merge(options))

        entry.input_vector.sitemap_entry = entry.get_sitemap_entry(
            url:  entry.input_vector.action,
            code: entry.page ? entry.page.response.code : 200
        )
        entry.input_vector.save

        entry.sitemap_entry = entry.input_vector.sitemap_entry
        entry.save

        entry
    end

    def update_state( state, reviewed_by_revision = nil )
        # Inefficient but we need to trigger a PaperTrail.
        Entry.reorder('').where( digest: digest ).each do |entry|
            entry.update(
                state:                   state,
                reviewed_by_revision_id: reviewed_by_revision ?
                                             reviewed_by_revision.id : nil
            )
        end
    end

    def get_sitemap_entry( options = {} )
        revision.sitemap_entries.create_with(options).
            find_or_create_by( url: options[:url] )
    end

    def set_owners
        # The revision setter handles this.
        self.revision = revision
    end

end
