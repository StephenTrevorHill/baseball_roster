# app/jobs/ping_job.rb
class PingJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("[PingJob] ran at #{Time.current}")
    puts "[PingJob] puts from worker at #{Time.current}"
  end
end
