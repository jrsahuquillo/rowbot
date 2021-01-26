require 'telegram/bot'

module BotCommand
  class Base
    attr_reader :user, :message, :api

    def initialize(user, message)
      @user = user
      @message = message
      token = Rails.application.credentials.dig(:bot_token)
      @api = ::Telegram::Bot::Api.new(token)
    end

    def should_start?
      raise NotImplementedError
    end

    def start
      raise NotImplementedError
    end

    protected

    def send_message(text, markup=nil, parse_mode=nil, options={})
      @api.call('sendMessage', chat_id: @user.telegram_id, text: text, reply_markup: markup, parse_mode: parse_mode)
    end

    def text
      @message[:message][:text]
    end

    def from
      @message[:message][:from]
    end
  end
end