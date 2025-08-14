# app/services/mlb/client.rb
require "faraday"

module Mlb
  class Client
    BASE = "https://statsapi.mlb.com"

    def initialize(base: BASE)
      @conn = Faraday.new(base) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.adapter Faraday.default_adapter
      end
    end

    # MLB (Major League) sportId=1. You can pass others (e.g., minors) if needed.
    def teams(sport_id: ENV.fetch("MLB_SPORT_ID", "1"))
      # Common endpoint for teams
      @conn.get("/api/v1/teams", { sportId: sport_id }).body.fetch("teams", [])
    end
  end
end
