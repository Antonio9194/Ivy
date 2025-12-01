
if ENV["OPENAI_ACCESS_TOKEN"].to_s.strip != ""
	OpenAI.configure do |config|
		config.access_token = ENV["OPENAI_ACCESS_TOKEN"]
	end
else
	# Do not configure OpenAI when the token is not present (e.g. during image/docker builds
	# or other environments where secrets are not provided). This prevents raising a
	# KeyError during `rails assets:precompile` which loads initializers.
	Rails.logger.info("OPENAI_ACCESS_TOKEN not set — skipping OpenAI configuration") if defined?(Rails)
end