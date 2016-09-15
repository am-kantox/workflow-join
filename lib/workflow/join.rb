require 'workflow'
require 'workflow/join/version'

Workflow::ClassMethods.prepend(Module.new do
  attr_reader :host

  def workflow(&specification)
    # extend instances
    prepend(Module.new do # this should be safe, since there could not be two subsequent workflow DSL
      attr_reader :pending_transitions # FIXME PERSIST!!!
      def guards!
        spec.instance_variable_set(:@host, self)
        λλs = spec.guards.map do |inner, outers|
                outers.map do |getter, state|
                  guard! inner, getter, state
                end
              end.flatten
        λλs << spec.before_transition_proc if spec.before_transition_proc
        spec.before_transition_proc = ->(from, to, name, *args) { λλs.each { |λ| λ.(from, to, name, *args) } }
      end

      def guard!(inner, getter, state)
        slave = getter.call
        slave.instance_variable_set(:@☛, (slave.instance_variable_get(:@☛) || []) | [self])
        slave_hook = "on_#{state}_entry".to_sym
        slave.class.prepend(Module.new do
          define_method slave_hook do |old_state, event, *args|
            @☛.each do |master|
              next unless master.pending_transitions.is_a?(Array)
              master.pending_transitions.reject! do |transition|
                begin
                  master.send("#{transition}!".to_sym)
                  true
                rescue
                  false # no transition no cry
                end
              end
            end
            super(old_state, event, *args) rescue nil # no super no cry
          end
        end)
        lambda do |_, to, name, *|
          if to.to_sym == inner && !slave.send("#{state}?".to_sym)
            (@pending_transitions ||= []) << name
            halt("Waiting for guard workflow to enter “:#{state}” state")
          end
        end
      end
    end)

    # extend singleton class to update guards in constructor
    singleton_class.prepend(Module.new do
      def new(*)
        super.tap(&:guards!)
      end
    end)

    super
  end
end)

module Workflow
  module Join
    GUARD_PARAMS_ERROR = 'Either guard instance variable name or a code block is required'.freeze
    GUARD_POINTCUT_ERROR = 'Both :inner and :outer states are required'.freeze
    GUARD_IS_NOT_WORKFLOW = 'Guard given must be a workflow instance'.freeze

    def guards
      @guards ||= {}
    end

    def guard(getter = nil, inner: nil, outer: nil)
      fail Workflow::WorkflowDefinitionError, GUARD_PARAMS_ERROR unless !getter.nil? ^ block_given?
      fail Workflow::WorkflowDefinitionError, GUARD_POINTCUT_ERROR unless inner && outer

      guard = if block_given?
                Proc.new
              else
                g = getter.to_sym
                lambda do
                  case
                  when /\A@/ =~ g.to_s && @host.instance_variable_defined?(g)
                    @host.instance_variable_get(g)
                  when @host.methods.include?(g) && @host.method(g).arity.zero?
                    @host.send g
                  end.tap do |guard_instance|
                    fail Workflow::WorkflowDefinitionError, GUARD_IS_NOT_WORKFLOW unless guard_instance.is_a?(Workflow)
                  end
                end
              end
      (guards[inner.to_sym] ||= []) << [guard, outer.to_sym]
    end
  end
end

Workflow::Specification.prepend Workflow::Join
