class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Tell Rails how to route roles → databases
  # :writing is your normal primary DB, :queue is the Solid Queue DB
  connects_to database: { writing: :primary, queue: :queue }
end
