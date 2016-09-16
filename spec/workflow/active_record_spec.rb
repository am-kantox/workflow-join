require 'spec_helper'

if Workflow::Join.const_defined?('ActiveRecord')

  Object.send(:remove_const, 'Master') if Kernel.const_defined?('Master')
  Object.send(:remove_const, 'Slave') if Kernel.const_defined?('Slave')

  ActiveRecord::Base.logger = Logger.new($stderr)

  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: ':memory:'
  )

  ActiveRecord::Schema.define do
    unless ActiveRecord::Base.connection.tables.include? 'masters'
      create_table :masters do |table|
        table.column :whatever,                     :string
        table.column :workflow_state,               :string
        table.column :workflow_pending_transitions, :string
        table.column :workflow_pending_callbacks,   :string
      end
    end

    unless ActiveRecord::Base.connection.tables.include? 'tracks'
      create_table :slaves do |table|
        table.column :master_id,                    :integer
        table.column :whatever,                     :string
        table.column :workflow_state,               :string
        table.column :workflow_pending_transitions, :string
        table.column :workflow_pending_callbacks,   :string
      end
    end
  end

  class Master < ActiveRecord::Base
    has_one :slave

    include Workflow

    workflow do
      state :meeting do
        event :go, transitions_to: :after_meeting
      end
      state :after_meeting

      # before entering :after_meeting state, wait for @slave to enter :resolved state
      guard :slave, inner: :after_meeting, outer: :resolved
      guard inner: :after_meeting, outer: :resolved, &:slave
    end
  end

  class Slave < ActiveRecord::Base
    belongs_to :master

    include Workflow

    workflow do
      state :unresolved do
        event :resolve, transitions_to: :resolved
      end
      state :resolved
    end
  end

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
