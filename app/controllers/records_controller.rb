class RecordsController < ApplicationController
  def index
    @records = Record.all
  end

  def show
    @record = Record.find(params[:id])
  end

  def create
    @chat = current_user.chats.build(chat_params)
    @record = Record.new
    if @record.save
      redirect_to root_path
    else
      flash.now[:alert] = "Oops, something went wrong. Please try again"
      render :index
    end
  end

  def update
    @record = Record.find(params[:id])
    
  end

  def destroy
    @record = Record.find(params[:id])
    @record.destroy
    if @record.save
      redirect_to records_path
    else
      flash.now[:alert] = "Oops, somethign went wrong. Please try again"
    end
  end

  private

  def record_params
    params.require(:record).permit(:title, :description, :status)
  end
end
