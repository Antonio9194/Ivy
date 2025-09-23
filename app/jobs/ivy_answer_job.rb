class IvyAnswerJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)
    user = chat.user

    # Generate a cache key for this chat
    cache_key = "ai_response_for_chat_#{chat.id}"

    # Try to fetch cached response first
    response_text, parsed_json = Rails.cache.fetch(cache_key, expires_in: 6.hours) do
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
        and also extract key tasks as JSON.

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
          "start_time": "... (ISO 8601 format, optional)",
          "end_time": "... (ISO 8601 format, optional)",
          "alert": "... (optional reminder text)"
        }
      PROMPT

      client = OpenAI::Client.new
      output = nil
      retries = 0

      begin
        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [{ role: "user", content: prompt }],
            temperature: 0.7
          }
        )
        output = response.dig("choices", 0, "message", "content")
      rescue Faraday::TooManyRequestsError, OpenAI::Error => e
        if e.message.include?("429") && retries < 5
          retries += 1
          sleep_time = (2 ** retries) + rand # exponential backoff with jitter
          Rails.logger.warn "Rate limited! Retry #{retries} after #{sleep_time}s for chat #{chat.id}"
          sleep(sleep_time)
          retry
        else
          Rails.logger.error "AI call failed for chat #{chat.id}: #{e.message}"
          next [nil, nil] # cache nil to avoid retry storms
        end
      end

      parsed = JSON.parse(output) rescue nil
      [output, parsed]
    end

    return unless parsed_json && response_text

    # Update chat with AI response
    chat.update(response: parsed_json["response_text"])

    # Create record if info exists
    if parsed_json["title"].present?
      Record.create!(
        title: parsed_json["title"],
        description: parsed_json["description"],
        status: parsed_json["status"] || "pending",
        user: user
      )
    end

    # Enqueue calendar event if start_time is present
    if parsed_json["start_time"].present? && parsed_json["title"].present?
      SaveEventToCalendarJob.perform_later(
        user.id,
        title: parsed_json["title"],
        description: parsed_json["description"],
        start_time: parsed_json["start_time"],
        end_time: parsed_json["end_time"],
        alert: parsed_json["alert"]
      )
    end
  end
end