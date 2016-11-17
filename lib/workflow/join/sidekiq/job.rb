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
          state DONE
          state :failed
        end

        def on_running_entry(_old_state, _event, *args)
          Worker.wrap(worker).perform_async(*args, ★: id) # FIXME: Anything more elegant?
        end

        def on_failed_entry(_old_state, _event, *args)
          (self.fails ||= {})[Time.zone.now] = args
        end

        ########################################################################

        serialize :args, Array
        serialize :result, Hash
        serialize :fails, Hash

        def to_hash
          {
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
      end
    end
  end
end
