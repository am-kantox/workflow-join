require 'spec_helper'

if Workflow::Join.const_defined?('ActiveRecord')
  describe Workflow::Join do
    let(:master) { Master.create!(whatever: 'I am master', workflow_state: 'meeting') }
    let(:raising_master) { RaisingMaster.create!(whatever: 'I am raising master', workflow_state: 'meeting') }
    let(:slave) { Slave.create!(whatever: 'I am slave :(', workflow_state: 'unresolved', master_id: master.id) }

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
      Workflow::Join::Sidekiq::Job::Worker.drain
      master.go!
      expect(master.after_meeting?).to be_truthy
    end

    it 'enters :after_meeting on slave set to :resolved' do
      master.go!
      slave.reload.resolve!
      Workflow::Join::Sidekiq::Job::Worker.drain
      expect(master.reload.after_meeting?).to be_truthy
      expect(master.pending_transitions).to be_empty
    end

    it 'raises an exception on draining job' do
      raising_master.go!
      expect { Workflow::Join::Sidekiq::Job::Worker.drain }.to raise_error(RuntimeError, 'Raised')
      expect(raising_master.pending_transitions).to match_array(%i|go|)
      expect(raising_master.meeting?).to be_truthy
      expect(Workflow::Join::Sidekiq::Job.where(workflow_state: 'failed').count).to eq(1)
    end
  end
end
