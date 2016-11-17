require 'workflow'
require 'workflow/join/version'

with_ar = if ENV['USE_SIMPLE_PERSISTENCE'] == 'true'
            require 'workflow/join/simple'
            puts "☆ Using simple mode (no persistence,) due to ‘ENV['USE_SIMPLE_PERSISTENCE']’"
          else
            begin
              require 'active_record'
              require 'workflow/join/active_record'
            rescue LoadError => e
              require 'workflow/join/simple'
              puts "★ Error requiring ActiveRecord (message: “#{e.message}”.) Will run in simple mode (no persistence.)"
            end
          end

# rubocop:disable Metrics/AbcSize
Workflow::ClassMethods.prepend(Module.new do
  def workflow(&specification)
    # extend instances
    prepend(Module.new do # this should be safe, since there could not be two subsequent workflow DSL
      if Workflow::Join.const_defined?('ActiveRecord')
        include Workflow::Join::ActiveRecord # AR pending transitions and callbacks implementation
      else
        include Workflow::Join::Simple # simple pending transitions and callbacks implementation
      end

      def guards!
        spec.instance_variable_set(:@original_before_transition_proc, spec.before_transition_proc) \
          unless spec.instance_variable_defined?(:@original_before_transition_proc)

        λλs = spec.guards.map do |inner, outers|
                outers.map do |getter, state|
                  guard! inner, getter, state
                end.compact
              end.flatten

        (original_before_transition_proc = spec.instance_variable_get(:@original_before_transition_proc)) && \
          λλs << original_before_transition_proc
        spec.before_transition_proc = ->(from, to, name, *args) { λλs.each { |λ| λ.(from, to, name, *args) } }
      end

      def guard!(inner, getter, state)
        return if getter.nil? || (slave = getter.call(self)).nil? # I’ll be back, hasta la vista, baby :)

        slave.class.send :define_method, "on_#{state}_entry".to_sym do |old_state, event, *args|
          pending_callbacks.each do |master|
            master.reload if master.respond_to?(:reload)
            next unless master.pending_transitions?
            master.try_pending_transitions!
            # halted is automagically removed after successful transition
            # the line below is unneeded
            # master.halted = master.pending_transitions?
          end
          super(old_state, event, *args) rescue nil # no super no cry
        end

        lambda do |_, to, name, *|
          slave.reload if slave.respond_to?(:reload)
          if to.to_sym == inner && !slave.send("#{state}?".to_sym)
            pending_transition! name
            slave.pending_callback!(self)
            halt("Waiting for guard workflow to enter “:#{state}” state")
          end
        end
      end
    end)

    if respond_to?(:after_commit)
      after_commit { guards! }
    else
      singleton_class.prepend(Module.new do
        def new(*)
          super.tap(&:guards!)
        end
      end)
    end

    super
  end
end)
# rubocop:enable Metrics/AbcSize

module Workflow
  module Join
    GUARD_PARAMS_ERROR = 'One of: [guard instance variable, code block, job] is required'.freeze
    GUARD_POINTCUT_ERROR = 'Both :inner and :outer state / :job are required'.freeze
    GUARD_IS_NOT_WORKFLOW = 'Guard given must be a workflow instance, was: “%s”'.freeze
    DEVELOPER_ERROR = 'Developer is an idiot, please excuse and file and issue'.freeze

    def guards
      @guards ||= {}
    end

    def guard(getter = nil, inner: nil, outer: nil, job: nil)
      fail Workflow::WorkflowDefinitionError, GUARD_PARAMS_ERROR unless [getter, job, block_given?].one?
      fail Workflow::WorkflowDefinitionError, GUARD_POINTCUT_ERROR unless inner && (outer || job)

      guard = case getter ||= job
              when NilClass then Proc.new # block_given? == true, see L#97 check
              when Symbol, String then guard_for_instance_variable(getter)
              when Class then guard_for_class(getter)
              else fail Workflow::WorkflowDefinitionError, DEVELOPER_ERROR
              end
      (guards[inner.to_sym] ||= []) << [guard, (outer || ::Workflow::Join::Sidekiq::Job::DONE).to_sym]
    end

    private

    def guard_for_instance_variable(getter)
      g = getter.to_sym
      lambda do |host|
        case
        when /\A@/ =~ g.to_s && host.instance_variable_defined?(g)
          host.instance_variable_get(g)
        when host.methods.include?(g) && host.method(g).arity <= 0
          host.send g
        end.tap do |guard_instance|
          fail Workflow::WorkflowDefinitionError, GUARD_IS_NOT_WORKFLOW % guard_instance \
            unless guard_instance.nil? || guard_instance.is_a?(Workflow)
        end
      end
    end

    def guard_for_class(getter)
      lambda do |host|
        Workflow::Join::Sidekiq::Job.lookup!(host, getter).tap do |job|
          job.run! if job.can_run?
        end
      end
    end
  end
end

Workflow::Specification.prepend Workflow::Join

require 'workflow/join/sidekiq' if with_ar
