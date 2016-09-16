module Workflow
  module Join
    module ActiveRecord
      # table.column :workflow_pending_callbacks,   :string
      module PendingCallbacks
        def pending_callbacks
          workflow_pending_callbacks.to_s.split(';').map do |wpc|
            c, id = wpc.split(',')
            Kernel.const_get(c).find(id) rescue nil
          end.compact
        end

        def pending_callbacks!(value)
          pcs = case value
                when Array then value.map { |instance| [instance.class.name, instance.id].join(',') }.join(';')
                when String, Symbol then value.to_s
                end
          update_column :workflow_pending_callbacks, pcs
        end

        def pending_callbacks?
          !pending_callbacks.empty?
        end

        def pending_callback!(value)
          pending_callbacks!(pending_callbacks | [value])
        end
      end
    end
  end
end
