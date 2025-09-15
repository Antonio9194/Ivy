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
    prompt = <<~PROMPT
      You are Ivy, a helpful assistant that answers the user in natural language
      and also extracts key tasks as JSON. 
      User message: "#{@chat.content}"
      Output format:
      {
        "response_text": "Human-readable answer to user",
        "title": "...",
        "description": "...",
        "status": "..."
      }
    PROMPT

    chat_ai = RubyLLM.chat
    response = chat_ai.ask(prompt)
    output = response.content

    parsed = JSON.parse(output) rescue nil
    if parsed
      @chat.update(response: parsed["response_text"])

      Record.create!(
        title: parsed["title"],
        description: parsed["description"],
        status: parsed["status"] || "pending"
      )
    end

    render :index
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