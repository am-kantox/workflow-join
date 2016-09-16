module Workflow
  module Join
    module Simple
      module PendingTransitions
        def pending_transitions
          @pending_transitions ||= []
        end

        def pending_transitions!(value)
          @pending_transitions = value
        end

        def pending_transitions?
          !pending_transitions.empty?
        end

        def pending_transition!(value)
          pending_transitions!(pending_transitions | [value])
        end

        def try_pending_transitions!
          pending_transitions.reject! do |transition|
            begin
              respond_to?("can_#{transition}?") && \
                public_send("can_#{transition}?") && \
                public_send("#{transition}!".to_sym) && \
                true
            rescue
              false # no transition no cry
            end
          end
        end
      end
    end
  end
end
