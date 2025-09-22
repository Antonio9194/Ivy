class IvyAnswerJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 5

  def perform(chat_id)
    sleep 2
    chat = Chat.find(chat_id)
    user = chat.user

    # --- Handle "delete all events" ---
    if chat.content.downcase.include?("delete all events")
      user.calendar_events.destroy_all
      chat.update(response: "Okay, I deleted all your events.")
      return
    end

    # --- Handle direct "delete event <title>" commands ---
    if chat.content.downcase.include?("delete event")
      # Extract the title from the message
      title_to_delete = chat.content.downcase.match(/delete event "?(.+?)"?$/)&.captures&.first
      if title_to_delete
        event = user.calendar_events.find_by("LOWER(title) = ?", title_to_delete.downcase)
        if event
          event.destroy
          chat.update(response: "Okay, I deleted the event '#{event.title}'.")
        else
          chat.update(response: "I couldn’t find any event called '#{title_to_delete}'.")
        end
        return
      end
    end

    # --- Build conversation history for AI ---
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

    # --- Build AI prompt ---
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

    # --- Call OpenAI API with retry/backoff ---
    retries = 0
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
    rescue Faraday::TooManyRequestsError
      retries += 1
      if retries <= MAX_RETRIES
        sleep_time = 2**retries
        Rails.logger.info "429 received, retrying in #{sleep_time}s (attempt #{retries})..."
        sleep(sleep_time)
        retry
      else
        Rails.logger.error "IvyAnswerJob failed after #{MAX_RETRIES} retries due to rate limits."
        chat.update(response: "Sorry, I’m busy right now. Please try again in a few seconds.")
        return
      end
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