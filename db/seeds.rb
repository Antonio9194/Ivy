# db/seeds.rb

puts "Destroying everything..."
Record.destroy_all
Chat.destroy_all
User.destroy_all

puts "Creating Ivy..."
User.create!(
  email: "ivy@system.local",
  name: "Ivy",
  password: SecureRandom.hex(10)
)

puts "Done!"