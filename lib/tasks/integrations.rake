# lib/tasks/integrations.rake
namespace :integrations do
  desc "Sync MLB teams into teams table"
  task sync_mlb_teams: :environment do
    if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::AsyncAdapter)
      puts "Dev async adapter detected — running inline…"
      SyncMlbTeams.call
    else
      has_queue_tables =
        (ApplicationRecord.connected_to(role: :queue) do
          ActiveRecord::Base.connection.data_source_exists?("solid_queue_jobs")
        end rescue false)

      if has_queue_tables
        SyncMlbTeamsJob.perform_later
        puts "Enqueued SyncMlbTeamsJob"
      else
        puts "Queue tables missing — running inline…"
        SyncMlbTeams.call
      end
    end
  end
end
