class SaveEventToCalendarJob < ApplicationJob
  queue_as :default

  # Arguments:
  #   user_id: Integer
  #   title: String
  #   description: String or nil
  #   start_time: DateTime
  #   end_time: DateTime or nil
  #   alert: String or nil (optional reminder text)
  def perform(user_id, title:, description: nil, start_time:, end_time: nil, alert: nil)
    user = User.find(user_id)

    # Create the calendar event for the user
    calendar_event = user.calendar_events.create!(
      title: title,
      description: description,
      start_time: start_time,
      end_time: end_time,
      alert: alert
    )

    # Optional: Log creation for debugging
    Rails.logger.info "Saved event '#{calendar_event.title}' for user #{user.id} starting at #{calendar_event.start_time}"

    # Optional: trigger alert/notification here
    # Example: AlertJob.perform_later(calendar_event.id) if calendar_event.alert.present?
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to save calendar event for user #{user_id}: #{e.message}"
  end
end