class SaveEventToCalendarJob < ApplicationJob
  queue_as :default

  def perform(user_id, title:, description: nil, start_time:, end_time: nil, alert: nil)
    user = User.find(user_id)

    ts = normalize_time(start_time)
    te = normalize_time(end_time) if end_time.present?

    return unless ts && title.present?

    begin
      CalendarEvent.transaction(requires_new: true) do
        event = user.calendar_events.find_or_initialize_by(title: title, start_time: ts)

        if event.new_record?
          event.description = description
          event.end_time    = te
          event.alert       = alert
          event.save!
          Rails.logger.info "SaveEventToCalendarJob: created event '#{event.title}' for user #{user.id} at #{event.start_time}"
        else
          Rails.logger.info "SaveEventToCalendarJob: event already exists (id=#{event.id}) for user #{user.id}"
        end
      end
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.info "SaveEventToCalendarJob: prevented duplicate for user #{user.id} title='#{title}' start=#{ts}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "SaveEventToCalendarJob: validation failed for user #{user.id} — #{e.record.errors.full_messages.join(', ')}"
    end
  end

  private

  def normalize_time(value)
    return nil if value.blank?

    t = if value.is_a?(String)
      Time.zone.parse(value) rescue Time.parse(value).in_time_zone
    elsif value.respond_to?(:to_time)
      value.to_time.in_time_zone
    end

    return nil unless t
    # Normalize to minute to avoid microsecond mismatches
    Time.zone.at((t.to_i / 60) * 60)
  end
end