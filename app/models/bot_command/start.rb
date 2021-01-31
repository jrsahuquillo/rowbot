module BotCommand
  class Start < Base
    def should_start?
      [
        '/start',
        '/ver_entrenamientos',
        '/administrar_entrenamientos',
        '/administrar_socios',
        '/unirse_entrenamiento',
        '/salir_entrenamiento',
        '/mis_entrenamientos'
      ].include?(text)
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
        user.set_next_step('gender')
        actions = ['Remera', 'Remero']
        send_message('¿Eres remero o remera?:', set_markup(actions))
      elsif user.enabled?
        actions = ['/ver_entrenamientos', '/mis_entrenamientos'], ['/unirse_entrenamiento', '/salir_entrenamiento']
        actions.unshift(['/administrar_entrenamientos'], ['/administrar_socios']) if user.admin?
        user.reset_next_bot_command
        send_message('Selecciona una opción:', set_markup(actions)) if text == '/start'

        case text
        when '/administrar_entrenamientos'
            actions = ['/crear_entrenamiento', '/editar_entrenamiento'], ['/ver_entrenamientos', '/borrar_entrenamiento']
            send_message('Administrar entrenamientos:', set_markup(actions))
            user.set_next_bot_command('BotCommand::AdminManageTraining')

        when '/administrar_socios'
          actions = []
          actions << ['/activar_socios'] if (User.where(enabled: false).present? || User.where(level: nil).present?)
          actions << ['/desactivar_socios'] if User.where(enabled: true).present?
          send_message('Opciones:', set_markup(actions))
          user.set_next_bot_command('BotCommand::AdminManageUser')

        when '/ver_entrenamientos'
          gender = user.gender == "female" ? "Femenino" : "Masculino"
          trainings = Training.where(level: user.level, gender: [gender, "Mixto"])
          if trainings.present?
            send_message('Próximos entrenamientos:')
            trainings_text = []
            trainings.sort_by(&:date).each do |training|
              trainings_text << "➤ *#{training.title}* - \[[#{training.users.size.to_s}/8\]]"
            end
            send_message(trainings_text.map(&:inspect).join("\n").tr('\"', ''), nil, 'Markdown')
          else
            send_message('No hay entrenamientos')
          end
          send_message('/start')

        when '/unirse_entrenamiento'
          gender = user.gender == "female" ? "Femenino" : "Masculino"
          trainings = []
          user_trainings = Training.where(level: user.level, gender: [gender, "Mixto"])
          if user_trainings.present?
            user_trainings.sort_by(&:date).each do |training|
              trainings <<  "#{training.title} - [#{training.users.size.to_s}/8]"
            end
            send_message("Selecciona el entrenamiento al que quieres unirte:", set_markup(trainings))
            user.set_next_bot_command('BotCommand::UserManageTraining')
            user.set_next_step('join_training')
          else
            send_message('No hay entrenamientos')
          end

        when '/salir_entrenamiento'
          trainings = []
          user_trainings = user.trainings
          if user_trainings.present?
            user_trainings.sort_by(&:date).each do |training|
              trainings <<  "#{training.title} - [#{training.users.size.to_s}/8]"
            end
            send_message("Selecciona el entrenamiento del que quieres salir:", set_markup(trainings))
            user.set_next_bot_command('BotCommand::UserManageTraining')
            user.set_next_step('exit_training')
          else
            send_message('No hay entrenamientos')
          end

        when '/mis_entrenamientos'
          user.set_next_step('my_trainings')
          user_trainings = user.trainings.sort_by(&:date).map{|training| "#{training.title} - \[#{training.users.size.to_s}/8\]"}
          if user_trainings.present?
            send_message('Selecciona qué entrenamiento quieres ver:', set_markup(user_trainings))
            user.set_next_bot_command('BotCommand::UserManageTraining')
            user.set_next_step('list_my_trainings')
          else
            send_message('No estás en ningún entrenamiento')
          end
        end

        else
          send_message('Espera a que un entrenador active tu cuenta. ⏳')
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
          send_message("¡#{welcome_gender} @#{user.username || user.first_name } 👋🏻!")
          if user.enabled?
            self.start
          else
            send_message('Espera a que un entrenador active tu cuenta. ⏳') unless user.enabled?
            send_new_user_to_admins(user)
          end
          user.reset_step
        end
      end
    end

    def send_new_user_to_admins(rower)
      admins_telegram_ids = User.where(role: 'admin').pluck(:telegram_id)
      message = "🔴 #{rower.username} (#{rower.first_name} #{rower.last_name}) está esperando a que le activen. Entra en /administrar_socios."
      admins_telegram_ids.each do |telegram_id|
        @api.call('sendMessage', chat_id: telegram_id, text: message, reply_markup: nil, parse_mode: nil)
      end
    end

    def get_custom_trainings(user)
      Training.where(level: "Paralímpico", gender: [gender, "Mixto"]) if user.level == "Paralímpico"
    end

  end
end