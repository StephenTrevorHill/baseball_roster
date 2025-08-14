# Rails Project Runbook — Baseball Roster App

> Living guide for local dev, jobs/queue health, data ops, commit hygiene, and Render deployment.

---

## 1) Local Dev Environment

### Start services

```bash
# Rails server (development)
bin/rails server

# Solid Queue worker (development)
RAILS_ENV=development bin/jobs start
```

### Enqueue a quick test job

```bash
bin/rails runner 'PingJob.perform_later'
```

### Inspect jobs & processes

```bash
# Last 5 jobs (quick view)
bin/rails runner 'ApplicationRecord.connected_to(role: :queue) { puts ActiveRecord::Base.connection.exec_query("SELECT id, class_name, queue_name, finished_at FROM solid_queue_jobs ORDER BY created_at DESC LIMIT 5").to_a }'

# Active Solid Queue processes (Supervisor/Dispatcher/Worker)
bin/rails runner 'ApplicationRecord.connected_to(role: :queue) { puts ActiveRecord::Base.connection.exec_query("SELECT kind, pid, name, metadata, last_heartbeat_at FROM solid_queue_processes ORDER BY last_heartbeat_at DESC").to_a }'

# Pauses
bin/rails runner 'ApplicationRecord.connected_to(role: :queue) { puts ActiveRecord::Base.connection.exec_query("SELECT * FROM solid_queue_pauses").to_a }'
```

---

## 2) Solid Queue Health

### Rake health check (JSON)

```bash
bin/rails "solid_queue:health[30,json]"
```

### Schema inspection helpers (SQLite)

```bash
# Table info
bin/rails runner 'ApplicationRecord.connected_to(role: :queue) { puts ActiveRecord::Base.connection.exec_query("PRAGMA table_info(solid_queue_jobs)").to_a }'

# List Solid Queue tables
bin/rails runner 'ApplicationRecord.connected_to(role: :queue) { puts ActiveRecord::Base.connection.exec_query("SELECT name FROM sqlite_master WHERE type=\'table\' AND name LIKE \'solid_queue%\' ORDER BY 1").to_a }'
```

---

## 3) MLB Team Sync

### Service file

`app/services/sync_mlb_teams.rb`

```ruby
# Maps only MLB teams (American + National Leagues)
# Safe handling of founded year and nested league/division
require "net/http"
require "json"

class SyncMlbTeams
  def self.call = new.call

  def call
    json = fetch!
    upsert(json)
  end

  private

  def fetch!
    uri = URI(ENV.fetch("MLB_API_BASE", "https://statsapi.mlb.com/api/v1/teams?activeStatus=Y"))
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.open_timeout = 5
      http.read_timeout = 10
      http.request(Net::HTTP::Get.new(uri))
    end
    raise "MLB API #{res.code}" unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body)
  end

  def upsert(payload)
    teams    = payload["teams"] || []
    upserted = 0
    skipped  = 0

    teams.each do |t|
      league_name   = t.dig("league", "name")
      next unless ["American League", "National League"].include?(league_name)

      first_year = t["firstYearOfPlay"]
      attrs = {
        mlb_team_id:  t["id"],
        name:         t["teamName"],
        city:         t["locationName"],
        abbreviation: t["abbreviation"],
        founded:      first_year&.to_i,
        league:       league_name,
        division:     t.dig("division", "name"),
        active:       t["active"]
      }.compact

      rec = Team.find_or_initialize_by(mlb_team_id: attrs[:mlb_team_id])
      rec.assign_attributes(attrs)

      if rec.new_record? || rec.changed?
        rec.save!
        upserted += 1
      else
        skipped += 1
      end
    end

    { upserted:, skipped:, total: teams.size }
  end
end
```

### One-off enqueue

```bash
# Rake task enqueues the job
bin/rails integrations:sync_mlb_teams
```

### Quick data checks in console

```ruby
# Show a sample team
Team.first.slice(:mlb_team_id, :name, :league, :division, :abbreviation, :active)

# Count by league
Team.group(:league).count
```

### Reset & resync

```bash
# Danger: deletes all teams
bin/rails runner 'Team.delete_all'
# Then re-enqueue sync
bin/rails integrations:sync_mlb_teams
```

---

## 4) Commit & Code Hygiene

### RuboCop (safe fixes only)

```bash
bundle exec rubocop -a
```

### Suggested pre-commit checklist

1. ✅ Tests: `bin/rails test` (or your test command)
2. ✅ Lint (safe fixes): `bundle exec rubocop -a`
3. ✅ Git status clean: `git status`
4. ✅ Commit with clear message

```bash
git add .
git commit -m "Implement MLB team sync with league/division filter and queue health rake"
```

> Optional (unsafe fixes too): `bundle exec rubocop -A`

---

## 5) Render Deployment

### Adapter & DB roles

- Ensure `config.active_job.queue_adapter = :solid_queue` (environment config)
- Ensure `ApplicationRecord` `connects_to` is correct for your primary/queue DB setup

### Migrations

```bash
bin/rails db:migrate
bin/rails db:migrate:queue
```

### Procfile

```procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec rails solid_queue:start
```

### Environment vars (Render)

```
RAILS_ENV=production
RAILS_MASTER_KEY=...           # from config/master.key or credentials
MLB_API_BASE=https://statsapi.mlb.com/api/v1/teams?activeStatus=Y
```

### Assets

```bash
bundle exec rails assets:precompile
```

### Local prod sanity check (optional)

```bash
RAILS_ENV=production bundle exec rails s
RAILS_ENV=production bundle exec rails solid_queue:start
```

### Post-deploy smoke test

```ruby
# In Rails console on Render
SyncMlbTeamsJob.perform_later
ApplicationRecord.connected_to(role: :queue) { SolidQueue::Job.last }
```

---

## 6) Handy Query Snippets (SQLite)

```bash
# Last 3 SyncMlbTeamsJob runs (safe quoting)
bin/rails runner 'ApplicationRecord.connected_to(role: :queue) {
  puts ActiveRecord::Base.connection.exec_query(
    "SELECT id, class_name, finished_at FROM solid_queue_jobs WHERE class_name = \'SyncMlbTeamsJob\' ORDER BY id DESC LIMIT 3"
  ).to_a
}'

# Failed executions (last 5)
bin/rails runner 'ApplicationRecord.connected_to(role: :queue) {
  puts ActiveRecord::Base.connection.exec_query(
    "SELECT job_id, error, created_at FROM solid_queue_failed_executions ORDER BY created_at DESC LIMIT 5"
  ).to_a
}'
```

---

## 7) Notes

- Prefer parameterized SQL or careful quoting when running raw SQL via `bin/rails runner`.
- The Solid Queue worker logs job `perform` entries; keep a worker terminal open during dev.
- Health rake `solid_queue:health` returns counts and stale process detection.

---

*Last updated: \<mm/dd/yyyy>*

