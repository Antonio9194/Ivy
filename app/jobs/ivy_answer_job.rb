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

    # Include user's previous calendar events
    events_info = user.calendar_events.order(:start_time).map do |e|
      "Title: #{e.title}, Description: #{e.description}, Start: #{e.start_time.strftime('%b %d, %Y %H:%M')}, End: #{e.end_time ? e.end_time.strftime('%b %d, %Y %H:%M') : 'N/A'}"
    end.join("\n")

    # Build AI prompt
    prompt = <<~PROMPT
      You are Ivy, a helpful assistant that answers the user in natural language,
      your job is to remember and store everything the user asks you to do,
      and also extracts key tasks as JSON.

      Conversation so far:
      #{chat_history}

      User's previous records:
      #{records_info}

      Attachments in this message:
      #{attachments_info}

      Calendar events:
      #{events_info}

      Latest user message:
      "#{chat.content}"

      Output format:
      {
        "response_text": "Human-readable answer to user",
        "title": "...",
        "description": "...",
        "status": "...",
        "start_time": "... (ISO 8601 format, optional if reminder)",
        "end_time": "... (ISO 8601 format, optional)",
        "alert": "... (optional reminder text)"
      }
    PROMPT

    # Call OpenAI API
    client = OpenAI::Client.new
    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.7
      }
    )
    output = response.dig("choices", 0, "message", "content")
    parsed = JSON.parse(output) rescue nil
    return unless parsed

    # Update chat with AI response
    chat.update(response: parsed["response_text"])

    # Create record if info exists
    if parsed["title"].present?
      Record.create!(
        title: parsed["title"],
        description: parsed["description"],
        status: parsed["status"] || "pending",
        user: user
      )
    end

    # Enqueue calendar event if start_time is present
    if parsed["start_time"].present? && parsed["title"].present?
      SaveEventToCalendarJob.perform_later(
        user.id,
        title: parsed["title"],
        description: parsed["description"],
        start_time: parsed["start_time"],
        end_time: parsed["end_time"],
        alert: parsed["alert"]
      )
    end
  end
end