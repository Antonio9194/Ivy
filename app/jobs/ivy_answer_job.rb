class IvyAnswerJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)
    user = chat.user

    # Build conversation history
    chat_history = user.chats.order(:created_at).map do |c|
      "#{c.sender_type || 'You'}: #{c.content}\nIvy: #{c.response}"
    end.join("\n")

    # Include user's previous records
    records_info = user.records.order(:created_at).map do |r|
      "Title: #{r.title}, Description: #{r.description}, Status: #{r.status}"
    end.join("\n")

    # Include attachments from this chat
    attachments_info = chat.attachments.map do |a|
      "#{a.photo.filename}" if a.photo.attached?
    end.compact.join(", ")

    prompt = <<~PROMPT
      You are Ivy, a helpful assistant that answers the user in natural language
      and also extracts key tasks as JSON.

      Conversation so far:
      #{chat_history}

      User's previous records:
      #{records_info}

      Attachments in this message:
      #{attachments_info}

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

    chat_ai = RubyLLM.chat
    response = chat_ai.ask(prompt)
    output = response.content

    parsed = JSON.parse(output) rescue nil
    if parsed
      chat.update(response: parsed["response_text"])
      Record.create!(
        title: parsed["title"],
        description: parsed["description"],
        status: parsed["status"] || "pending",
        user: user
      )
    end
  end
end