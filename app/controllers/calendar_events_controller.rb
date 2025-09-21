class CalendarEventsController < ApplicationController
  def index
    @calendar_events = current_user.calendar_events.order(:start_time)
  end

  def show
    @calendar_event = current_user.calendar_events.find(params[:id])
  end

  def new
    @calendar_event = current_user.calendar_events.new
  end

  def create
    @calendar_event = current_user.calendar_events.new(calendar_event_params)
    if @calendar_event.save
      redirect_to calendar_events_path, notice: "Event created successfully"
    else
      flash.now[:alert] = "Unable to create new event"
      render :new
    end
  end

  def edit
    @calendar_event = current_user.calendar_events.find(params[:id])
  end

def update
  @calendar_event = current_user.calendar_events.find(params[:id])
  if @calendar_event.update(calendar_event_params)
    redirect_to calendar_event_path(@calendar_event), notice: "Event updated successfully."
  else
    flash.now[:alert] = "Unable to update event."
    render :edit
  end
end

  def destroy
    @calendar_event = current_user.calendar_events.find(params[:id])
    @calendar_event.destroy
    redirect_to calendar_events_path
  end

  private

  def calendar_event_params
    params.require(:calendar_event).permit(:title, :description, :start_time, :end_time, :alert)
  end
end
