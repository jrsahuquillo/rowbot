module BotCommand
  class Undefined < Base
    def start
      send_message('Comando desconocido. Usa /start para ver las opciones')
    end
  end
end