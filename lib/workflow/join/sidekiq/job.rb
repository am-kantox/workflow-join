module Workflow
  module Join
    module Sidekiq
      class Job < ::ActiveRecord::Base
        attr_accessor :worker, :args, :result, :errors

        class << self
          def migration(table_name = 'workflow_jobs')
            <<-MIGRATION
            class CreateWorkflowJobs < ::ActiveRecord::Migration
              def change
                create_table :#{table_name} do |t|
                  t.string   :workflow_state, default: 'uninitialized', null: false

                  t.string   :worker
                  t.text     :args
                  t.text     :result
                  t.text     :errors

                  t.string   :workflow_pending_transitions
                  t.string   :workflow_pending_callbacks

                  t.timestamps
                end

                add_index :#{table_name}, :workflow_state, unique: false
              end
            end
            MIGRATION
          end
        end

        include Workflow
        workflow do
          state :scheduled do
            event :run, transitions_to: :running
          end
          state :running do
            event :fail, transitions_to: :failed
            event :success, transitions_to: :done
          end
          state :done
          state :failed
        end

        serialize :args, Array
        serialize :result, Hash
        serialize :errors, Hash

        def error!(e)
          (self.errors ||= {})[Time.zone.now] = e
          fail!
          fail e
        end

        def to_hash
          {
            worker: worker,
            args: args,
            result: result,
            errors: errors,
            workflow_state: workflow_state,
            state: workflow_state.to_sym
          }
        end
      end
    end
  end
end
