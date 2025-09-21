puts "Destroying everything..."

# Destroy attachments first to avoid orphaned ActiveStorage records
ActiveStorage::Attachment.destroy_all
ActiveStorage::Blob.destroy_all

# Destroy dependent models
Record.destroy_all
CalendarEvent.destroy_all
Chat.destroy_all

# Finally, destroy users
User.destroy_all

puts "Creating Ivy..."
User.create!(
  email: "ivy@system.local",
  name: "Ivy",
  password: SecureRandom.hex(10)
)
puts "Creating Antonio..."
User.create!(
  email: "anto.vinciguerra@hotmail.com",
  name: "Antonio",
  password: "password"
)

puts "Done!"