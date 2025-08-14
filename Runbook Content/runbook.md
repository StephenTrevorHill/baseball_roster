Got it — before we work on deployment, make sure your code changes are pushed to your remote repo. Here’s your quick push checklist:

1. **Verify branch**

```bash
git branch
```

2. **Ensure working directory is clean**

```bash
git status
```

3. **Push committed changes**

```bash
git push origin <branch-name>
```

Replace `<branch-name>` with the current branch (e.g., `main` or `dev`).

4. **Confirm remote**

```bash
git remote -v
```

Once pushed, we’ll move into the **Render deployment** steps from the runbook — starting with environment variables, migrations, and the Procfile configuration.



## Render Deployment (Rails + Postgres + Solid Queue)

### 0) Assumptions
- Rails 8 app currently uses SQLite locally, Postgres in production.
- Solid Queue is installed and migrations have been run locally.
- You have a Render account and the GitHub repo connected.

---
### 1) Gem & config prep (local)
1. **Gemfile**
   ```ruby
   # Gemfile
   gem "pg", group: [:production]
   gem "sqlite3", group: [:development, :test]
   ```
   ```bash
   bundle install
   git add Gemfile Gemfile.lock && git commit -m "Use pg in production"
   ```
2. **config/database.yml (production)**
   ```yaml
   production:
     url: <%= ENV["DATABASE_URL"] %>
     pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
     # Solid Queue uses the same DB by default; no special role DB needed in prod
   ```
   ```bash
   git add config/database.yml && git commit -m "Prod uses DATABASE_URL"
   ```

> If you use credentials for `secret_key_base` (recommended), ensure `config/master.key` is **not** committed. You'll pass `RAILS_MASTER_KEY` to Render.

---
### 2) Create the Postgres service on Render
1. Render dashboard → **New → PostgreSQL**.
2. Pick a region (match your future web service region).
3. Create the DB. Copy both **Internal Database URL** and **External Database URL**.
   - Prefer **Internal** for your web/worker services.

---
### 3) Create the Web Service (Rails app)
**New → Web Service** → connect your GitHub repo.

**Environment**
- Add these env vars:
  - `DATABASE_URL` = *Internal Database URL* from step 2
  - `RAILS_ENV` = `production`
  - `RACK_ENV` = `production`
  - `RAILS_LOG_LEVEL` = `info` (or `debug` while testing)
  - `RAILS_MASTER_KEY` = contents of `config/master.key`
  - (Optional) `SECRET_KEY_BASE` **only** if you don’t store it in credentials

**Build Command** (choose what matches your JS setup):
- Importmap / no Node:
  ```bash
  bundle install && bundle exec rails assets:precompile
  ```
- jsbundling-rails (esbuild/rollup/webpack):
  ```bash
  bundle install && yarn install --frozen-lockfile && bundle exec rails assets:precompile
  ```

**Start Command**
```bash
bundle exec rails server -p $PORT
```
> If you use Puma explicitly, Render detects `puma`; either is fine.

**Postdeploy Command**
```bash
bundle exec rails db:migrate
```

Click **Create Web Service**.

---
### 4) Create the Background Worker (Solid Queue)
Create another service: **New → Worker** (same repo/branch/region).

**Environment**: duplicate the env vars from the Web Service (especially `DATABASE_URL` and `RAILS_MASTER_KEY`).

**Start Command** (pick one that matches your project):
```bash
bundle exec bin/jobs start
```
_or_
```bash
bundle exec rails solid_queue:start
```
Scale to **1 instance** to start.

> Solid Queue stores state in Postgres; no Redis/Sidekiq required. Ensure the worker and web point to the **same** DB.

---
### 5) First deploy sanity checks
- Watch build logs finish, then the web service should go **Healthy**.
- Open the web service URL. If you don’t have a root page, temporarily add a route or use `/rails/info/routes` while testing (disable in prod later).
- From Render → Web Service → **Shell**:
  ```bash
  bundle exec rails db:version
  bundle exec rails runner "puts Team.count"
  ```
- From Render → Worker → **Logs**: you should see Solid Queue Supervisor/Dispatcher/Worker heartbeats.

---
### 6) Data seeding / one-off tasks
If you need initial data:
```bash
bundle exec rails db:seed
```
If you need to kick the MLB sync once in prod:
```bash
bundle exec rails integrations:sync_mlb_teams
```
Watch worker logs to confirm execution.

---
### 7) Optional: `render.yaml` (in-repo declarative setup)
Create `render.yaml` at repo root to codify the services:
```yaml
services:
  - type: web
    name: baseball-roster-web
    env: ruby
    buildCommand: |
      bundle install && bundle exec rails assets:precompile
    startCommand: bundle exec rails server -p $PORT
    plan: starter
    envVars:
      - key: RAILS_ENV
        value: production
      - key: RACK_ENV
        value: production
      - key: RAILS_LOG_LEVEL
        value: info
      - key: DATABASE_URL
        fromDatabase:
          name: baseball-roster-db
          property: connectionStringInternal
      - key: RAILS_MASTER_KEY
        sync: false   # set in dashboard
    postDeployCommand: bundle exec rails db:migrate

  - type: worker
    name: baseball-roster-worker
    env: ruby
    buildCommand: |
      bundle install && bundle exec rails assets:precompile
    startCommand: bundle exec bin/jobs start
    plan: starter
    envVars:
      - key: RAILS_ENV
        value: production
      - key: RACK_ENV
        value: production
      - key: RAILS_LOG_LEVEL
        value: info
      - key: DATABASE_URL
        fromDatabase:
          name: baseball-roster-db
          property: connectionStringInternal
      - key: RAILS_MASTER_KEY
        sync: false

databases:
  - name: baseball-roster-db
    plan: starter
```
Commit this file and enable **Auto-Deploy** on Render so changes apply on push.

---
### 8) Gotchas & tips
- **SQLite in prod:** Not supported on Render; Postgres is required.
- **Master key:** If missing/incorrect, boot will fail with credentials errors.
- **Assets:** If you see 404s on CSS/JS, ensure `assets:precompile` ran and `public/assets` is present after build.
- **Migrations:** Keep `postDeploy` as `db:migrate`; it runs after each successful build.
- **Time zones:** Set `RAILS_TIME_ZONE` (optional) and ensure you use `Time.zone` consistently.
- **Active Storage:** If you start storing files, configure S3/GCS for `production` (Render disk is ephemeral).

---
### 9) Rollback
If a release fails after migration:
```bash
# Deploy previous commit via Render Rollback UI
# Then (if needed) rollback schema
bundle exec rails db:rollback STEP=1
```

---
### 10) Post-deploy health check (Solid Queue)
From the web service shell:
```bash
bundle exec rails "solid_queue:health[30,json]"
```
You should see active Supervisor/Dispatcher/Worker and low failure counts.

