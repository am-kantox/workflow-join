require 'workflow/join/active_record/pending_transitions'
require 'workflow/join/active_record/pending_callbacks'

module Workflow
  module Join
    module ActiveRecord
      ENSURE_COLUMNS = lambda do |model, *columns|
        columns.reduce(true) do |memo, column|
          next memo if model.column_names.include?(column.to_s)

          ::ActiveRecord::Base.connection.execute(
            "ALTER TABLE #{model.table_name} ADD #{column} VARCHAR(255)"
          )
          false
        end
      end

      include PendingTransitions
      include PendingCallbacks

      def self.included(base)
        base.singleton_class.send :define_method, :prepended do |model|
          fail LoadError, "This module might be included in ActiveRecord::Base instances only (#{base} given.)" \
            unless model < ::ActiveRecord::Base

          unless ENSURE_COLUMNS.call(model, :workflow_pending_transitions, :workflow_pending_callbacks)
            fail LoadError, <<-MSG

              =======================================================================================
               This is an intended fail, next time the class is requested, it’ll be loaded properly!
               To avoid this one should explicitly specify columns:
                  — workflow_pending_transitions,
                  — workflow_pending_callbacks
               in all models, that are willing to use joined workflows.
              =======================================================================================

            MSG
          end
        end
      end
    end
  end
end
