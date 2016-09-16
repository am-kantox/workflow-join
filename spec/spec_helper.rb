$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'workflow/join'

require 'pry'

class Master
  include Workflow

  attr_accessor :slave

  def initialize(*)
    @slave = Slave.new
  end

  workflow do
    state :meeting do
      event :go, transitions_to: :after_meeting
    end
    state :after_meeting

    # before entering :after_meeting state, wait for @slave to enter :resolved state
    guard :@slave, inner: :after_meeting, outer: :resolved
    guard :slave, inner: :after_meeting, outer: :resolved
    guard inner: :after_meeting, outer: :resolved, &:slave
  end
end

class Slave
  include Workflow

  workflow do
    state :unresolved do
      event :resolve, transitions_to: :resolved
    end
    state :resolved
  end
end
