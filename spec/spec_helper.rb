# $LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'workflow/join'

require 'pry'
require 'logger'

describe Workflow::Join do
  it 'has a version number' do
    expect(Workflow::Join::VERSION).not_to be nil
  end
end

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

else

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

end
