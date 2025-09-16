class AttachmentsController < ApplicationController
  def index
    @attachments = current_user.attachments
  end

  def show
    @attachment = @attachments.find(params[:id])
  end

  def create
    @attachment = Attachment.new(attachment_params)
    if @attachment.save
      flash[:notice] = "File uploaded succesffully!"
      redirect_back(fallback_location: root_path)
    else
      flash[:alert] = "Failed to upload."
      redirect_back(fallback_location: root_path)
    end
  end

  private

  def attachment_params
    params.require(:attachment).permit(:photo, :chat_id)
  end
end
