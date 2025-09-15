class ChatsController < ApplicationController
  before_action :authenticate_user!

  # Display chat page
  def index
    @chats = current_user.chats.includes(:attachments).order(created_at: :asc)
    @chat = Chat.new
  end

  # Handle new chat submission
  def create
    @chat = Chat.new(chat_params)
    @chat.user = current_user

    if @chat.save
      # Build conversation history to feed to AI
      chat_history = current_user.chats.order(:created_at).map do |c|
        "#{c.sender_type || 'You'}: #{c.content}\nIvy: #{c.response}"
      end.join("\n")

      # Prompt for AI
      prompt = <<~PROMPT
        You are Ivy, a helpful assistant that answers the user in natural language
        and also extracts key tasks as JSON.

        Conversation so far:
        #{chat_history}

        Latest user message:
        "#{@chat.content}"

        Output format:
        {
          "response_text": "Human-readable answer to user",
          "title": "...",
          "description": "...",
          "status": "..."
        }
      PROMPT
      puts "Sending prompt to RubyLLM:"
puts prompt

      # Call the AI
      chat_ai = RubyLLM.chat
      response = chat_ai.ask(prompt)
      output = response.content
            puts "Received response from RubyLLM:"
puts output

      # Parse AI output
      parsed = JSON.parse(output) rescue nil
      if parsed
        # Update chat with Ivy's response
        @chat.update(response: parsed["response_text"])

        # Create structured Record
        Record.create!(
          title: parsed["title"],
          description: parsed["description"],
          status: parsed["status"] || "pending",
          user: current_user
        )
      end

      # Reload chats for index view
      @chats = current_user.chats.includes(:attachments).order(created_at: :asc)

      render :index
    else
      @chats = current_user.chats.includes(:attachments).order(created_at: :asc)
      flash.now[:alert] = "Oops, something went wrong. Please try again."
      render :index
    end
  end

  private

  def chat_params
    params.require(:chat).permit(:content, :sender_type, attachments_attributes: [:file, :file_type])
  end
end