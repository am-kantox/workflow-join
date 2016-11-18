module Workflow
  module Join
    module Sidekiq
      class Job < ::ActiveRecord::Base
        # attr_accessor :worker, :args, :result, :fails
        DONE = :done
        TABLE_NAME = 'workflow_jobs'.freeze

        self.table_name = TABLE_NAME

        class << self
          def migration(table_name = TABLE_NAME)
            <<-MIGRATION
            class CreateWorkflowJobs < ::ActiveRecord::Migration
              def change
                create_table :#{table_name} do |t|
                  t.string   :workflow_state, default: 'scheduled', null: false

                  t.string   :host
                  t.integer  :host_id
                  t.string   :worker

                  t.text     :args
                  t.text     :result
                  t.text     :fails

                  t.string   :workflow_pending_transitions
                  t.string   :workflow_pending_callbacks

                  t.timestamps
                end

                add_index :#{table_name}, :workflow_state, unique: false
                add_index :#{table_name}, [:host, :host_id, :worker], unique: true
              end
            end
            MIGRATION
          end

          def lookup!(host, worker)
            params = { host: host.class.to_s, host_id: host.id, worker: worker.to_s }
            where(**params).last || create!(**params)
          end

          def worker(worker)
            case worker
            when String, Symbol then Kernel.const_get(worker)
            when Module then worker
            else fail ArgumentError, "Workflow::Join::Sidekiq::Job#worker expects a string/class as an argument, got #{worker.inspect}."
            end
          end
        end

        private_class_method :new, :create, :create! # use lookup!, buddy

        ########################################################################

        include Workflow

        workflow do
          state :scheduled do
            event :run, transitions_to: :running
          end
          state :running do
            event :fail, transitions_to: :failed
            event :success, transitions_to: DONE
          end
          state :failed do
            event :success, transitions_to: DONE
          end
          state DONE
        end

        def on_running_entry(_old_state, _event, *args)
          Job::Worker.perform_async(*args, ★: id) # FIXME: Anything more elegant?
        end

        def on_failed_entry(_old_state, _event, *args)
          timestamp = Time.respond_to?(:zone) && Time.zone ? Time.zone.now : Time.now
          (self.fails ||= {})[timestamp] = args
        end

        ########################################################################

        serialize :args, Array
        serialize :result, Hash
        serialize :fails, Hash

        def to_hash
          {
            # id: id,
            host: host,
            host_id: host_id,
            worker: worker,
            args: args,
            result: result,
            errors: fails,
            workflow_state: workflow_state,
            state: workflow_state.to_sym
          }
        end

        ########################################################################

        class Worker
          include ::Sidekiq::Worker

          def perform(*args)
            Job.find(args.pop['★']).tap do |job|
              # FIXME: Log this somehow
              begin
                job.args = [*args, job.to_hash]
                job.result = Job.worker(job.worker).new.perform(*job.args)
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
end
