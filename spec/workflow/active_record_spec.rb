require 'spec_helper'

if Workflow::Join.const_defined?('ActiveRecord')
  describe Workflow::Join do
    let(:master) { Master.create!(whatever: 'I am master', workflow_state: 'meeting') }
    let(:slave)  { Slave.create!(whatever: 'I am slave :(', workflow_state: 'unresolved', master_id: master.id) }

    before do
      slave.reload
      master.reload
      master.whatever += ' :)'
      master.save!
    end

    it 'halts unless slave is :resolved' do
      master.go!
      expect(master.pending_transitions).to match_array(%i|go|)
      expect(master.meeting?).to be_truthy
    end

    it 'enters :after_meeting when slave was already :resolved' do
      slave.resolve!
      master.go!
      expect(master.after_meeting?).to be_truthy
    end

    it 'enters :after_meeting on slave set to :resolved' do
      master.go!
      slave.reload.resolve!
      expect(master.reload.after_meeting?).to be_truthy
      expect(master.pending_transitions).to be_empty
    end
  end
end
