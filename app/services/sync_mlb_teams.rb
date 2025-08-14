# app/services/sync_mlb_teams.rb
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
    teams = payload["teams"] || []
    upserted = 0
    skipped  = 0

    teams.each do |t|
      next unless t.dig("sport", "name") == "Major League Baseball"
      first_year = t["firstYearOfPlay"]
      attrs = {
          mlb_team_id:  t["id"],
          name:         t["teamName"],
          city:         t["locationName"],
          abbreviation: t["abbreviation"],
          founded:      first_year&.to_i,
          league:       t.dig("league", "name"),
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
