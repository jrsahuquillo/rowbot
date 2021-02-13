module BotCommand
  class Undefined < Base
    def start
      send_message(I18n.t('unknown_command'))
    end
  end
end