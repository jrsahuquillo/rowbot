module BotCommand
  class Start < Base
    def should_start?
      commands = [
                  '/start',
                  '/ver_entrenamientos',
                  '/unirse_entrenamiento',
                  '/salir_entrenamiento',
                  '/mis_entrenamientos'
                ]
        commands << '/administrar_entrenamientos' if user.trainer? || user.admin?
        commands << '/administrar_socios' if user.admin?
      commands.include?(text)
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
        send_message(I18n.t('start.insert_username'), nil, 'Markdown') if user.username.nil?
      elsif user.gender.nil?
        user.set_next_step('gender')
        actions = ['Remera', 'Remero']
        send_message(I18n.t('start.which_rower_gender'), set_markup(actions))
      elsif user.enabled?
        actions = ['/ver_entrenamientos', '/mis_entrenamientos'], ['/unirse_entrenamiento', '/salir_entrenamiento']
        actions.unshift(['/administrar_entrenamientos'], ['/administrar_socios']) if user.admin?
        user.reset_next_bot_command
        send_message(I18n.t('start.option_select'), set_markup(actions)) if text == '/start'

        case text
        when '/administrar_entrenamientos'
          actions = ['/crear_entrenamiento', '/editar_entrenamiento'], ['/ver_entrenamientos', '/borrar_entrenamiento']
          send_message(I18n.t('manage_trainings.manage_trainings'), set_markup(actions))
          user.set_next_bot_command('BotCommand::AdminManageTraining')

        when '/administrar_socios'
          actions = []
          actions << ['/activar_socios'] if (User.where(enabled: false).present? || User.where(level: nil).present?)
          actions << ['/desactivar_socios'] if User.where(enabled: true).present?
          send_message(I18n.t('start.options'), set_markup(actions))
          user.set_next_bot_command('BotCommand::AdminManageUser')

        when '/ver_entrenamientos'
          gender = user.gender == "female" ? "Femenino" : "Masculino"
          trainings = Training.joinable.where(level: user.level, gender: [gender, "Mixto"])
          if trainings.present?
            send_message(I18n.t('start.next_trainings'))
            trainings_text = []
            trainings.sort_by(&:date).each do |training|
              trainings_text << "▶️ *#{training.title}* - \[[#{training.users.size.to_s}/#{training.capacity}\]]"
            end
            send_message(trainings_text.map(&:inspect).join("\n").tr('\"', ''), nil, 'Markdown')
          else
            send_message(I18n.t('start.not_trainings'))
          end
          send_message('/start', set_remove_kb)

        when '/unirse_entrenamiento'
          gender = user.gender == "female" ? "Femenino" : "Masculino"
          trainings = []
          user_trainings = Training.joinable.where(level: user.level, gender: [gender, "Mixto"])
          if user_trainings.present?
            user_trainings.sort_by(&:date).each do |training|
              trainings <<  "#{training.title} - [#{training.users.size.to_s}#{training.capacity}]"
            end
            send_message(I18n.t('start.select_trainings.join'), set_markup(trainings))
            user.set_next_bot_command('BotCommand::UserManageTraining')
            user.set_next_step('join_training')
          else
            send_message(I18n.t('start.not_trainings'))
          end

        when '/salir_entrenamiento'
          trainings = []
          user_trainings = user.trainings.joinable
          if user_trainings.present?
            user_trainings.sort_by(&:date).each do |training|
              trainings <<  "#{training.title} - [#{training.users.size.to_s}/#{training.capacity}]"
            end
            send_message(I18n.t('start.select_trainings.join'), set_markup(trainings))
            user.set_next_bot_command('BotCommand::UserManageTraining')
            user.set_next_step('exit_training')
          else
            send_message(I18n.t('start.not_trainings'))
          end

        when '/mis_entrenamientos'
          user.set_next_step('my_trainings')
          user_trainings = user.trainings.joinable.sort_by(&:date).map{|training| "▶️ #{training.title} - \[#{training.users.size.to_s}/#{training.capacity}\]"}
          if user_trainings.present?
            send_message(I18n.t('start.select_trainings.show'), set_markup(user_trainings))
            user.set_next_bot_command('BotCommand::UserManageTraining')
            user.set_next_step('list_my_trainings')
          else
            send_message(I18n.t('start.not_in_trainings'))
          end
        end

        else
          send_message(I18n.t('start.wait_activation'))
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
            send_message(I18n.t('start.wait_activation')) unless user.enabled?
            send_new_user_to_admins(user)
          end
          user.reset_step
        end
      end
    end

    def send_new_user_to_admins(rower)
      admins_telegram_ids = User.where(role: 'admin').pluck(:telegram_id)
      message = I18n.t('start.waiting_activation', username: rower.username, first_name: rower.first_name, last_name: rower.last_name)
      admins_telegram_ids.each do |telegram_id|
        @api.call('sendMessage', chat_id: telegram_id, text: message, reply_markup: nil, parse_mode: nil)
      end
    end

  end
end