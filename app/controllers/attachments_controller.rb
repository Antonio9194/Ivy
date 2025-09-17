class AttachmentsController < ApplicationController
  before_action :authenticate_user!
  def index
    @attachments = current_user.attachments
  end

  def show
    @attachment = @attachments.find(params[:id])
  end

def download
  attachment = Attachment.find(params[:id])
  if attachment.photo.attached?
    send_data attachment.photo.download,
              filename: attachment.photo.filename.to_s,
              disposition: "attachment"
  else
    redirect_to attachments_path, alert: "No file attached."
  end
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

def destroy
  attachment = Attachment.find_by(id: params[:id])
  if attachment
    attachment.destroy
    redirect_to attachments_path, notice: "File deleted."
  else
    redirect_to attachments_path, alert: "File not found."
  end
end

  private

  def attachment_params
    params.require(:attachment).permit(:photo, :chat_id)
  end
end
