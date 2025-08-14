# lib/tasks/solid_queue_health.rake
namespace :solid_queue do
  desc "Check Solid Queue health: process heartbeats and queue depth"
  task :health, [ :stale_seconds, :format ] => :environment do |_t, args|
    require "active_record"
    require "time"
    require "json"

    threshold = (args[:stale_seconds] || 30).to_i
    format    = (args[:format] || "text").downcase

    ApplicationRecord.connected_to(role: :queue) do
      conn = ActiveRecord::Base.connection

      processes = conn.exec_query(<<~SQL)
        SELECT kind, name, last_heartbeat_at
        FROM solid_queue_processes
        ORDER BY kind
      SQL

      counts_sql = {
        ready:            "SELECT COUNT(*) AS c FROM solid_queue_ready_executions",
        scheduled:        "SELECT COUNT(*) AS c FROM solid_queue_scheduled_executions",
        claimed:          "SELECT COUNT(*) AS c FROM solid_queue_claimed_executions",
        failed:           "SELECT COUNT(*) AS c FROM solid_queue_failed_executions",
        blocked:          "SELECT COUNT(*) AS c FROM solid_queue_blocked_executions",
        unfinished_jobs:  "SELECT COUNT(*) AS c FROM solid_queue_jobs WHERE finished_at IS NULL"
      }

      counts = counts_sql.transform_values { |sql| conn.exec_query(sql).first["c"].to_i }

      now = Time.now.utc
      stale = processes.to_a.select do |p|
        last = Time.parse(p["last_heartbeat_at"].to_s) rescue Time.at(0)
        (now - last) > threshold
      end

      result = {
        threshold_seconds: threshold,
        processes: processes.to_a,
        counts: counts,
        stale_processes: stale,
        status: stale.any? ? "error" : "ok"
      }

      if format == "json"
        puts JSON.pretty_generate(result)
        exit(stale.any? ? 1 : 0)
      else
        puts "\n=== Solid Queue Health ==="
        puts "Processes (stale if > #{threshold}s without heartbeat):"
        processes.each do |p|
          puts "  #{p['kind']}: #{p['name']} — last beat #{p['last_heartbeat_at']}"
        end

        puts "\nQueue counts:"
        counts.each { |k, v| puts "  #{k.to_s.gsub('_', ' ').capitalize}: #{v}" }

        if stale.any?
          puts "\nERROR: Stale processes detected:"
          stale.each { |p| puts "  #{p['kind']} — #{p['name']}" }
          exit 1
        else
          puts "\nOK: All processes healthy."
        end
      end
    end
  end
end
