require 'telegram/bot'

module BotCommand
  class Base
    attr_reader :user, :message, :api
    LEVELS = [["Iniciación", "Fitness"], ["Competición", "Paralímpico"]]
    GENDERS = ["Mixto", "Femenino", "Masculino"]
    BOATS = [["Falucho", "Llaüt"], ["Yola", "Dos de Mar"]]
    ROLES = [["Entrenador/a", "Remero/a"]]

    def initialize(user, message)
      @user = user
      @message = message
      token = Rails.application.secrets.dig(:bot_token)
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
      @message[:message][:text] rescue nil
    end

    def data
      @message[:callback_query][:data] rescue nil
    end

    def from
      @message[:message][:from]
    end

    def set_markup(actions)
      Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: actions, one_time_keyboard: true, resize_keyboard: true)
    end

    def set_remove_kb
      Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
    end
  end
end