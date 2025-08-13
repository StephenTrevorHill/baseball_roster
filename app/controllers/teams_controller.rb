class TeamsController < ApplicationController
  def index
    @teams = Team.all
  end
  
  def show
    @team = Team.find(params[:id])
    @players = @team.players.order(:jersey_number)
  end
  
  def new
    @team = Team.new
  end
  
  def create
    @team = Team.new(team_params)

    if @team.save
      redirect_to @team, notice: 'Team created successfully!'
    else
    puts "DEBUG: Save failed, rendering :new with errors: #{@team.errors.full_messages}"
    render :new
    end
  end
  
  private
  
  def team_params
    params.require(:team).permit(:name, :city, :founded)
  end
end