class WebhooksController < ApplicationController
  http_basic_authenticate_with name: Rails.application.secrets[:http_name], password: Rails.application.secrets[:http_pass], only: :main
  helper_method :main
  skip_before_action :verify_authenticity_token

  def main
    secrets = Rails.application.secrets
    host = Rails.application.config.action_controller.default_url_options[:host]
    uri = URI("https://api.telegram.org/bot#{secrets[:bot_token]}/setWebhook?url=#{host}/telegram_#{secrets[:telegram_token]}")
    response = Net::HTTP.get(uri)
    json_response = JSON.parse(response)
    Rails.logger.info("Webhook status: #{json_response['description']}")
    status = JSON.parse(response)['ok'] == true ? "online" : "offline"
    @main = "Rowbot is #{status}"
  end

  def callback
    dispatcher.new(webhook, user).process
    render body: nil, head: :ok
    # redirect_back(fallback_location: root_path)
  end

  def webhook
    params['webhook']
  end

  def dispatcher
    BotMessageDispatcher
  end

  def from
    return webhook[:message][:from] if webhook[:message]
    return webhook[:callback_query][:from] if webhook[:callback_query]
  end

  def user
    @user ||= User.find_by(telegram_id: from[:id]) || register_user
  end

  def register_user
    @user = User.find_or_initialize_by(telegram_id: from[:id])
    @user.update(username: from[:username], first_name: from[:first_name], last_name: from[:last_name])
    @user
  end
end