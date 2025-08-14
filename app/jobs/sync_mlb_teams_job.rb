# app/jobs/sync_mlb_teams_job.rb
class SyncMlbTeamsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform
    Rails.logger.info("[SyncMlbTeamsJob] starting at #{Time.current}")
    puts "[SyncMlbTeamsJob] perform starting #{Time.current}"
    result = SyncMlbTeams.call
    Rails.logger.info("[SyncMlbTeamsJob] done upserted=#{result[:upserted]} skipped=#{result[:skipped]}")
    puts "[SyncMlbTeamsJob] done upserted=#{result[:upserted]} skipped=#{result[:skipped]}"
  end
end
