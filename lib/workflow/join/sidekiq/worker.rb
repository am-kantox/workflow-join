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

          def wrap(worker)
            case worker
            when String, Symbol then Kernel.const_get(worker)
            when Module then worker
            else fail ArgumentError, "Workflow::Join::Sidekiq::Worker#wrap expects a string/class as an argument, got #{worker.inspect}."
            end.prepend Workflow::Join::Sidekiq::Worker
          end
        end

        def perform(*args)
          Job.find(args.pop['★']).tap do |job|
            begin
              job.args = args
              job.result = super(*job.args)
              job.success!
            rescue => e
              job.fail! e
              raise e
            end
          end
        end
      end
    end
  end
end
