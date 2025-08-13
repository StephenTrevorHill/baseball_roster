class PlayersController < ApplicationController
  before_action :find_team
  
  def show
    @player = @team.players.find(params[:id])
  end

  def new
    @player = @team.players.build
  end
  
  def create
    @player = @team.players.build(player_params)
    
    if @player.save
      redirect_to @team, notice: 'Player added successfully!'
    else
      render :new
    end
  end
  
  def destroy
    @player = @team.players.find(params[:id])
    @player.destroy
    redirect_to @team, notice: 'Player removed from team.'
  end
  
  private
  
  def find_team
    @team = Team.find(params[:team_id])
  end
  
  def player_params
    params.require(:player).permit(:name, :position, :jersey_number)
  end
end