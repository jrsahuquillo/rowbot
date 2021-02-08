# Be sure to restart your server when you modify this file.

# ActiveSupport::Reloader.to_prepare do
#   ApplicationController.renderer.defaults.merge!(
#     http_host: 'example.org',
#     https: false
#   )
# end

secrets = Rails.application.secrets
host = Rails.application.config.action_controller.default_url_options[:host]
uri = URI("https://api.telegram.org/bot#{secrets[:bot_token]}/setWebhook?url=#{host}/telegram_#{secrets[:telegram_token]}")
response = Net::HTTP.get(uri)
json_response = JSON.parse(response)
Rails.logger.info("Webhook status: #{json_response['description']}")