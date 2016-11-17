require 'spec_helper'

unless Workflow::Join.const_defined?('ActiveRecord')
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
