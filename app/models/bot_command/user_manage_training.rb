module BotCommand
  class UserManageTraining < Base
    def should_start?
      [
        '/crear_entrenamiento',
      ].include?(text)
    end
  end
end