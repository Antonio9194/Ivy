class IvyAnswerJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)
    user = chat.user

    content = chat.content.downcase

    # --- Handle "delete all events" ---
    if content.include?("delete all events")
      user.calendar_events.destroy_all
      chat.update(response: "Okay, I deleted all your events.")
      return
    end

    # --- Handle delete by date/time ---
    if content.include?("delete")
      # Try to extract date and optional time
      if (date_match = content.match(/(\d{1,2}(?:st|nd|rd|th)?\s+of\s+\w+\s+\d{4})/))
        date_str = date_match[1]
        date = Date.parse(date_str) rescue nil

        time = nil
        if (time_match = content.match(/at\s+(\d{1,2}(?::\d{2})?)/))
          time_str = time_match[1]
          time = Time.parse("#{date_str} #{time_str}") rescue nil
        end

        if date
          # If time is provided, match exact start_time
          if time
            event = user.calendar_events.find_by(start_time: time)
          else
            # Otherwise, match any event on that day
            event = user.calendar_events.where(start_time: date.beginning_of_day..date.end_of_day).first
          end

          if event
            event.destroy
            chat.update(response: "Okay, I deleted the event '#{event.title}'.")
          else
            chat.update(response: "I couldn’t find any event on #{date_str}#{time ? " at #{time_str}" : ""}.")
          end
          return
        end
      end
    end

    # --- Build conversation history for AI ---
    chat_history = user.chats.order(:created_at).map do |c|
      "#{c.sender_type || 'You'}: #{c.content}\nIvy: #{c.response}"
    end.join("\n")

    records_info = user.records.order(:created_at).map do |r|
      "Title: #{r.title}, Description: #{r.description}, Status: #{r.status}"
    end.join("\n")

    attachments_info = chat.attachments.map do |a|
      "#{a.photo.filename}" if a.photo.attached?
    end.compact.join(", ")

    events_info = user.calendar_events.order(:start_time).map do |e|
      "Title: #{e.title}, Description: #{e.description}, Start: #{e.start_time.strftime('%b %d, %Y %H:%M')}, End: #{e.end_time ? e.end_time.strftime('%b %d, %Y %H:%M') : 'N/A'}"
    end.join("\n")

    prompt = <<~PROMPT
      You are Ivy, a helpful assistant that answers the user in natural language
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

    # --- Call OpenAI API ---
    begin
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
    rescue StandardError => e
      Rails.logger.error "IvyAnswerJob failed: #{e.message}"
      chat.update(response: "Oops, something went wrong while processing your request.")
      return
    end

    # --- Update chat with AI response ---
    chat.update(response: parsed["response_text"])

    # --- Create record if info exists ---
    if parsed["title"].present?
      Record.create!(
        title: parsed["title"],
        description: parsed["description"],
        status: parsed["status"] || "pending",
        user: user
      )
    end

    # --- Enqueue calendar event if start_time is present ---
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