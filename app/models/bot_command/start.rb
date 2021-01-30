module BotCommand
  class Start < Base
    def should_start?
      text =~ /\A\/start/ ||
              (/\A\/administrar_entrenamientos/ if user.admin?)
    end

    def should_step?
      steps = ['gender']
      current_step = user.bot_command_data['step']
      if current_step && steps.include?(current_step)
        true
      else
        user.reset_next_bot_command
        false
      end
    end

    def start
      if user.username.nil?
        user.update_column(:username, from[:username]) if from[:username].present?
        send_message('Por favor, añade tu *username* en la configuración de Telegram', nil, 'Markdown') if user.username.nil?
      elsif user.gender.nil?
        actions = ['Remera', 'Remero']
        send_message('¿Eres remero o remera?:', set_markup(actions))
        user.set_next_step('gender')
        user.save
      elsif user.enabled?
        actions = ['/ver_entrenamientos', '/mis_entrenamientos'], ['/unirse_entrenamiento', '/salir_entrenamiento']
        actions.unshift(['/administrar_entrenamientos'], ['/administrar_usuarios']) if user.admin?
        send_message('Selecciona una opción:', set_markup(actions))
        user.reset_next_bot_command

        case text
        when '/administrar_entrenamientos'
            actions = ['/crear_entrenamiento', '/editar_entrenamiento'], ['/ver_entrenamientos', '/borrar_entrenamiento']
            send_message('Administrar entrenamientos:', set_markup(actions))
            user.set_next_bot_command('BotCommand::ManageTraining')
            user.set_next_step('manage_trainings')
        end
      else
        send_message('Espera a que un entrenador active tu cuenta.')
      end
    end

    def trigger_step
      case user.next_step
      when 'gender'
        if ['Remero', 'Remera'].include?(text)
          user.gender = 'female' if text == 'Remera'
          user.gender = 'male' if text == 'Remero'
          user.save
          welcome_gender = user.gender == 'female' ? 'Bienvenida' : 'Bienvenido'
          send_message("¡#{welcome_gender} @#{user.username || user.first_name }!")
          if user.enabled?
            self.start
          else
            send_message('Espera a que un entrenador active tu cuenta.') unless user.enabled?
          end
          user.reset_step
        end
      end
    end

    def set_markup(actions)
      Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: actions, one_time_keyboard: true, resize_keyboard: true)
    end
  end
end