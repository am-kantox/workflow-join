require 'workflow/join/simple/pending_transitions'
require 'workflow/join/simple/pending_callbacks'

module Workflow
  module Join
    module Simple
      include PendingTransitions
      include PendingCallbacks
    end
  end
end
