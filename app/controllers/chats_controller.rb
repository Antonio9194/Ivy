class ChatsController < ApplicationController
  before_action :authenticate_user!

  def index
    @chats = Chat.includes(:attachments).order(created_at: :asc)
    @chat = Chat.new
  end

def create
  @chat = Chat.new(chat_params)
  @chat.user = current_user

  if @chat.save
    GenerateRecordFromChatJob.perform_later(@chat)  # queue the AI processing
    redirect_to root_path
  else
    @chats = Chat.includes(:attachments).order(:created_at)
    flash.now[:alert] = "Oops, something went wrong. Please try again."
    render :index
  end
end

  private

  def chat_params
    params.require(:chat).permit(:content, :sender_type, attachments_attributes: [:file, :file_type])
  end
end