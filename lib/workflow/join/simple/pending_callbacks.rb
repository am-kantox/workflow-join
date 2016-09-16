module Workflow
  module Join
    module Simple
      module PendingCallbacks
        def pending_callbacks
          @pending_callbacks ||= []
        end

        def pending_callbacks!(value)
          @pending_callbacks = value
        end

        def pending_callbacks?
          !pending_callbacks.empty?
        end

        def pending_callback!(value)
          pending_callbacks!(pending_callbacks | [value])
        end
      end
    end
  end
end
