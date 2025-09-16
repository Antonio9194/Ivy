class IvyAnswerJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)
    user = chat.user

    # Build conversation history
    chat_history = user.chats.order(:created_at).map do |c|
      "#{c.sender_type || 'You'}: #{c.content}\nIvy: #{c.response}"
    end.join("\n")

    # Prompt for AI
    prompt = <<~PROMPT
      You are Ivy, a helpful assistant that answers the user in natural language
      and also extracts key tasks as JSON.

      Conversation so far:
      #{chat_history}

      Latest user message:
      "#{chat.content}"

      Output format:
      {
        "response_text": "Human-readable answer to user",
        "title": "...",
        "description": "...",
        "status": "..."
      }
    PROMPT

    # Call the AI
    chat_ai = RubyLLM.chat
    response = chat_ai.ask(prompt)
    output = response.content

    # Parse AI output
    parsed = JSON.parse(output) rescue nil
    if parsed
      # Update chat with Ivy's response
      chat.update(response: parsed["response_text"])

      # Create structured Record
      Record.create!(
        title: parsed["title"],
        description: parsed["description"],
        status: parsed["status"] || "pending",
        user: user
      )
    end
  end
end