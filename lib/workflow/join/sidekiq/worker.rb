module Workflow
  module Join
    module Sidekiq
      module Worker
        class << self
          def prepended(base)
            base.send(:include, ::Sidekiq::Worker) unless worker?(base)
          end

          def included(base)
            fail ArgumentError, "Workflow::Join::Sidekiq::Worker module must be prepended, not #{__callee__} (@ #{base})."
          end
          alias_method :extended, :included

          def worker?(base)
            base.ancestors.include?(::Sidekiq::Worker)
          end
        end

        def perform(*args)
          Job.create!(args: args, worker: self.class.to_s).tap do |job|
            begin
              job.run!
              job.result = super
              job.success!
            rescue => e
              job.error! e
            end
          end
        end
      end
    end
  end
end
