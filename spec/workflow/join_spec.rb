require 'spec_helper'

unless Workflow::Join.const_defined?('ActiveRecord')

  Object.send(:remove_const, 'SimpleMaster') if Kernel.const_defined?('SimpleMaster')
  Object.send(:remove_const, 'SimpleSlave') if Kernel.const_defined?('SimpleSlave')

  class SimpleMaster
    include Workflow

    attr_accessor :slave

    def initialize(*)
      @slave = SimpleSlave.new
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

  class SimpleSlave
    include Workflow

    workflow do
      state :unresolved do
        event :resolve, transitions_to: :resolved
      end
      state :resolved
    end
  end

  describe Workflow::Join do
    let(:master) { SimpleMaster.new }
    let(:slave)  { master.slave }

    it 'halts unless slave is :resolved' do
      master.go!
      expect(master.meeting?).to be_truthy
      expect(master.pending_transitions).to match_array(%i|go|)
    end

    it 'enters :after_meeting when slave was already :resolved' do
      slave.resolve!
      master.go!
      expect(master.after_meeting?).to be_truthy
    end

    it 'enters :after_meeting on slave set to :resolved' do
      master.go!
      slave.resolve!
      expect(master.after_meeting?).to be_truthy
      expect(master.pending_transitions).to be_empty
    end
  end

end
