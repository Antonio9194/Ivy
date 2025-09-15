class RecordsController < ApplicationController
  def index
    @records = Record.all
  end

  def show
    @record = Record.find(params[:id])
  end


  def update
    @record = Record.find(params[:id])
    if @record.update(record_params)
      redirect_to records_path, notice: "Record updated successfully."
    else
      flash.now[:alert] = "Failed to update record."
      render :show
    end
  end

  def destroy
    @record = Record.find(params[:id])
    @record.destroy
    redirect_to records_path, notice: "Record deleted successfully."
  end

  private

  def record_params
    params.require(:record).permit(:title, :description, :status)
  end
end
