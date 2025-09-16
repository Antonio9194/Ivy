class ChatsController < ApplicationController
  before_action :authenticate_user!

  # Display chat page
  def index
    @chats = current_user.chats.includes(:attachments).order(created_at: :asc)
    @chat = Chat.new
  end

# Handle new chat submission
def create
  @chat = current_user.chats.new(chat_params)

  respond_to do |format|
    if @chat.save
      # Enqueue Ivy’s response generation in background
      IvyAnswerJob.perform_later(@chat.id)

      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          "chat-container",
          partial: "chats/chat",
          locals: { chat: @chat }
        )
      end
      format.html { redirect_to chats_path }
    else
      format.turbo_stream { render :index, status: :unprocessable_entity }
      format.html { render :index, status: :unprocessable_entity }
    end
  end
end

  private

  def chat_params
    params.require(:chat).permit(:content, :sender_type, attachments_attributes: [:file, :file_type])
  end
end