# Ruby on Rails Development Runbook

## Initial Setup (One-time)

### 1. Install Ruby with rbenv (macOS)
```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install rbenv and ruby-build
brew install rbenv ruby-build

# Configure shell (add to ~/.zshrc)
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(rbenv init -)"' >> ~/.zshrc

# Reload shell
source ~/.zshrc

# Install Ruby
rbenv install 3.2.0
rbenv global 3.2.0

# Verify installation
ruby -v
which ruby  # Should show rbenv path

# Install Rails
gem install rails
rbenv rehash  # Refresh executable shims
rails -v
```

### 2. Troubleshooting rbenv
```bash
# Check rbenv versions
rbenv versions

# Refresh shims after installing gems
rbenv rehash

# Check PATH includes rbenv
echo $PATH | grep rbenv
```

## Project Creation

### Create New Rails App
```bash
rails new project_name --database=sqlite3
cd project_name
```

### Start Development Server
```bash
rails server
# Visit http://localhost:3000
# Stop with Ctrl+C
```

## Database Operations

### Generate Models
```bash
# Basic model
rails generate model ModelName field1:string field2:integer

# Model with relationships
rails generate model Player name:string position:string jersey_number:integer team:references
```

### Migrations
```bash
# Run pending migrations
rails db:migrate

# Check migration status
rails db:migrate:status

# Rollback last migration
rails db:rollback
```

### Seeds (Sample Data)
```bash
# Create sample data (edit db/seeds.rb first)
rails db:seed

# Reset database and re-seed
rails db:reset
```

### Database Console
```bash
# Rails console for testing models
rails console

# Example console commands:
# team = Team.new(name: "Yankees", city: "New York")
# team.save
# Team.all
# exit
```

## Controllers and Views

### Generate Controllers
```bash
rails generate controller ControllerName action1 action2 action3
# Example: rails generate controller Teams index show new create
```

### Check Routes
```bash
rails routes
# Shows all available routes in your app
```

## Common Development Commands

### Server Management
```bash
# Start server
rails server

# Start on different port
rails server -p 3001

# Start in production mode
rails server -e production
```

### Code Generation
```bash
# Generate model
rails generate model ModelName field:type

# Generate controller
rails generate controller ControllerName actions

# Generate full scaffold (model + controller + views)
rails generate scaffold ModelName field:type
```

### Database Commands
```bash
# Create databases
rails db:create

# Run migrations
rails db:migrate

# Seed database
rails db:seed

# Reset database (drop, create, migrate, seed)
rails db:reset

# Check pending migrations
rails db:migrate:status
```

## File Locations Reference

### Key Files and Directories
```
app/
├── controllers/          # Business logic
│   ├── teams_controller.rb
│   └── players_controller.rb
├── models/              # Data models
│   ├── team.rb
│   └── player.rb
├── views/               # Templates
│   ├── layouts/
│   │   └── application.html.erb
│   ├── teams/
│   └── players/
config/
├── routes.rb            # URL routing
└── database.yml         # Database configuration
db/
├── migrate/             # Database migrations
├── seeds.rb            # Sample data
└── development.sqlite3  # SQLite database file
Gemfile                  # Ruby dependencies
```

### Route Configuration (config/routes.rb)
```ruby
Rails.application.routes.draw do
  root 'teams#index'
  
  resources :teams, only: [:index, :show, :new, :create] do
    resources :players, only: [:show, :new, :create, :destroy]
  end
end
```

## Common Rails Patterns

### Model Relationships
```ruby
# One-to-many relationship
class Team < ApplicationRecord
  has_many :players, dependent: :destroy
  validates :name, presence: true
end

class Player < ApplicationRecord
  belongs_to :team
  validates :name, presence: true
end
```

### Controller Patterns
```ruby
class TeamsController < ApplicationController
  def index
    @teams = Team.all
  end
  
  def show
    @team = Team.find(params[:id])
  end
  
  def new
    @team = Team.new
  end
  
  def create
    @team = Team.new(team_params)
    if @team.save
      redirect_to @team, notice: 'Success!'
    else
      render :new
    end
  end
  
  private
  
  def team_params
    params.require(:team).permit(:name, :city, :founded)
  end
end
```

### Form Helpers (ERB Templates)
```erb
<!-- Form with validation errors -->
<%= form_with(model: @team, local: true, data: { turbo: false }) do |form| %>
  <% if @team.errors.any? %>
    <div class="error">
      <% @team.errors.full_messages.each do |message| %>
        <p><%= message %></p>
      <% end %>
    </div>
  <% end %>

  <%= form.label :name %>
  <%= form.text_field :name %>
  <%= form.submit %>
<% end %>

<!-- Links -->
<%= link_to "Text", path, class: "btn" %>

<!-- Buttons for DELETE requests -->
<%= button_to "Delete", path, method: :delete, 
              data: { confirm: "Are you sure?" } %>
```

## Troubleshooting

### Common Issues

**Permission Error Installing Gems:**
```bash
# Use rbenv instead of system Ruby
rbenv install 3.2.0
rbenv global 3.2.0
```

**Rails Command Not Found:**
```bash
rbenv rehash
```

**Form Not Submitting Correctly (Turbo Issues):**
```erb
<!-- Add data: { turbo: false } to forms -->
<%= form_with(model: @model, data: { turbo: false }) do |form| %>

<!-- Add to delete links -->
<%= button_to "Delete", path, method: :delete, data: { turbo: false } %>
```

**Migration Errors:**
```bash
# Check what migrations are pending
rails db:migrate:status

# Run specific migration
rails db:migrate VERSION=20231201000001
```

### Debugging

**Check Server Logs:**
- Watch terminal where `rails server` is running
- Look for request method (GET, POST, DELETE)
- Check for errors in red

**Rails Console for Testing:**
```bash
rails console
# Test models directly:
# Team.create(name: "Test", city: "Test")
# Team.all
```

## Deployment Preparation

### For Production (Render/Heroku)
```ruby
# Update Gemfile for PostgreSQL
group :production do
  gem 'pg'
end

group :development, :test do
  gem 'sqlite3'
end
```

### Environment Check
```bash
# Check current environment
rails console
Rails.env

# Run in production mode locally
rails server -e production
```

## ERB Template Reference

### ERB Syntax
```erb
<%= %>  <!-- Execute and output -->
<% %>   <!-- Execute but don't output -->
<%# %>  <!-- Comment -->

<!-- Variables from controller -->
<%= @team.name %>

<!-- Loops -->
<% @teams.each do |team| %>
  <%= team.name %>
<% end %>

<!-- Conditionals -->
<% if @teams.any? %>
  <p>We have teams!</p>
<% else %>
  <p>No teams yet.</p>
<% end %>
```

### Common Rails Helpers
```erb
<!-- Links -->
<%= link_to "Team Name", team_path(team) %>
<%= link_to "Back", :back %>

<!-- Forms -->
<%= form_with(model: @team) do |form| %>
  <%= form.text_field :name %>
  <%= form.submit %>
<% end %>

<!-- Images/Assets -->
<%= image_tag "logo.png" %>
<%= stylesheet_link_tag "application" %>
```

This runbook covers all the essential commands and patterns from our Rails development session!