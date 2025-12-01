OpenAI.configure do |config|
  config.access_token = ENV["OPENAI_ACCESS_TOKEN"] || "dummy_token_for_build"
end