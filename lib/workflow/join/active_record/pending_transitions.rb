module Workflow
  module Join
    module ActiveRecord
      # table.column :workflow_pending_transitions, :string
      module PendingTransitions
        def pending_transitions
          workflow_pending_transitions.to_s.split(',').map(&:to_sym)
        end

        def pending_transitions!(value)
          pts = case value
                when Array then value.map(&:to_s).join(',')
                when String, Symbol then value.to_s
                end
          update_column :workflow_pending_transitions, pts
        end

        def pending_transitions?
          !pending_transitions.empty?
        end

        def pending_transition!(value)
          pending_transitions!(pending_transitions | [value])
        end

        def try_pending_transitions!
          pending_transitions!(pending_transitions.reject do |transition|
            begin
              respond_to?("can_#{transition}?") && \
                public_send("can_#{transition}?") && \
                public_send("#{transition}!".to_sym) && \
                true
            rescue
              false # no transition no cry
            end
          end)
        end
      end
    end
  end
end
