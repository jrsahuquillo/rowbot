module BotCommand
  class UserManageTraining < Base
    def should_start?
      text =~ /\A\/crear_entrenamiento/
    end
  end
end