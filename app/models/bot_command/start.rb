module BotCommand
  class Start < Base
    def should_start?
      text =~ /\A\/start/
    end

    def start
      send_message('Selecciona una opción:')
      user.reset_next_bot_command
      user.set_next_bot_command('BotCommand::Start')
    end
  end
end