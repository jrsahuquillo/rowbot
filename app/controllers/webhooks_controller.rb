class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def main
    @text = "RowBot is online"
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
    webhook[:message][:from]
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