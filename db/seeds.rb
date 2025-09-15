User.find_or_create_by!(email: "ivy@system.local") do |user|
  user.full_name = "Ivy"
  user.password = SecureRandom.hex(10)
end