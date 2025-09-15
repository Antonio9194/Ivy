class GenerateRecordFromChatJob < ApplicationJob
  queue_as :default

  def perform(chat)
    prompt = <<~PROMPT
      You are Ivy, a helpful assistant that extracts key tasks or notes and MEMORISE EVERYTHING from user chats.
      User message: "#{chat.content}"
      Output as JSON: { "title": "...", "description": "...", "status": "..." }
    PROMPT

    response = RubyLLM.chat(messages: [{ role: "user", content: prompt }])
    output = response.content

    parsed = JSON.parse(output) rescue nil
    return unless parsed

    Record.create!(
      title: parsed["title"],
      description: parsed["description"],
      status: parsed["status"] || "pending",
      user: chat.user
    )
  end
end