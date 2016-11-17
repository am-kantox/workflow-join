require 'active_record'

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

  unless ActiveRecord::Base.connection.tables.include? 'slaves'
    create_table :slaves do |table|
      table.column :master_id,                    :integer
      table.column :whatever,                     :string
      table.column :workflow_state,               :string
      table.column :workflow_pending_transitions, :string
      table.column :workflow_pending_callbacks,   :string
    end
  end

  unless ActiveRecord::Base.connection.tables.include? 'workflow_jobs'
    create_table :workflow_jobs do |table|
      table.column :workflow_state,               :string

      table.column :host,                         :string
      table.column :host_id,                      :integer

      table.column :worker,                       :string
      table.column :args,                         :text
      table.column :result,                       :text
      table.column :fails,                        :text
      table.column :workflow_pending_transitions, :string
      table.column :workflow_pending_callbacks,   :string
    end
  end
end
