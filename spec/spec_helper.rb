# $LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'pry'
require 'logger'

require_relative 'spec_sqlite_helper' unless ENV['USE_SIMPLE_PERSISTENCE'] == 'true'

require 'rspec-sidekiq'
require 'workflow/join'

describe Workflow::Join do
  it 'has a version number' do
    expect(Workflow::Join::VERSION).not_to be nil
  end
end

if Workflow::Join.const_defined?('ActiveRecord')

  Object.send(:remove_const, 'Master') if Kernel.const_defined?('Master')
  Object.send(:remove_const, 'Slave') if Kernel.const_defined?('Slave')

  class MasterChecker
    include ::Sidekiq::Worker

    def perform(*args)
      fail "★★★ Args: #{args.inspect}" unless args.first.values_at(:host, :worker) == %w|Master MasterChecker|
      { ok: args }
    end
  end

  class MasterRaisingChecker
    include ::Sidekiq::Worker

    def perform(*_args)
      fail 'Raised'
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
      guard inner: :after_meeting, job: MasterChecker
    end
  end

  class RaisingMaster < Master
    workflow do
      state :meeting do
        event :go, transitions_to: :after_meeting
      end
      state :after_meeting

      # before entering :after_meeting state, wait for @slave to enter :resolved state
      # guard :slave, inner: :after_meeting, outer: :resolved
      # guard inner: :after_meeting, outer: :resolved, &:slave
      guard inner: :after_meeting, job: MasterRaisingChecker
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
