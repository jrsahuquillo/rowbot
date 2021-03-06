module BotCommand
  class Start < Base
    def should_start?
      commands = [
                  '/start',
                  '/help',
                  '/ver_entrenos',
                  '/unirse_entreno',
                  '/salir_entreno',
                  '/mis_entrenos',
                  '/cuenta_banco'
                ]
        commands << '/administrar_entrenos' if user.trainer? || user.admin?
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
        actions = ['/ver_entrenos', '/mis_entrenos'], ['/unirse_entreno', '/salir_entreno']
        actions.unshift(['/administrar_entrenos']) if user.trainer?
        actions.unshift(['/administrar_entrenos'], ['/administrar_socios']) if user.admin?
        user.reset_next_bot_command
        send_message(I18n.t('start.option_select'), set_markup(actions)) if text == '/start'

        case text
        when '/administrar_entrenos'
          actions = ['/crear_entreno', '/editar_entreno'], ['/ver_entrenos', '/borrar_entreno']
          send_message(I18n.t('manage_trainings.manage_trainings'), set_markup(actions))
          user.set_next_bot_command('BotCommand::AdminManageTraining')

        when '/administrar_socios'
          actions = []
          actions << ['/activar_socios'] if (User.where(enabled: false).present? || User.where(level: nil).present?)
          actions << ['/desactivar_socios'] if User.where(enabled: true).present?
          send_message(I18n.t('start.options'), set_markup(actions))
          user.set_next_bot_command('BotCommand::AdminManageUser')

        when '/ver_entrenos'
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
          send_message(I18n.t('start.start'), set_remove_kb)

        when '/unirse_entreno'
          gender = user.gender == "female" ? "Femenino" : "Masculino"
          trainings = []
          user_trainings = Training.joinable.where(level: user.level, gender: [gender, "Mixto"])
          if user_trainings.present?
            user_trainings.sort_by(&:date).each do |training|
              trainings <<  "#{training.title} - [#{training.users.size.to_s}/#{training.capacity}]"
            end
            send_message(I18n.t('start.select_trainings.join'), set_markup(trainings))
            user.set_next_bot_command('BotCommand::UserManageTraining')
            user.set_next_step('join_training')
          else
            send_message(I18n.t('start.not_trainings'))
          end

        when '/salir_entreno'
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

        when '/mis_entrenos'
          user.set_next_step('my_trainings')
          user_trainings = user.trainings.joinable.sort_by(&:date).map{|training| "▶️ #{training.title} - \[#{training.users.size.to_s}/#{training.capacity}\]"}
          if user_trainings.present?
            send_message(I18n.t('start.select_trainings.show'), set_markup(user_trainings))
            user.set_next_bot_command('BotCommand::UserManageTraining')
            user.set_next_step('list_my_trainings')
          else
            send_message(I18n.t('start.not_in_trainings'))
          end

        when '/help'
          send_message(I18n.t('start.help'))
          host = Rails.application.config.action_controller.default_url_options[:host]
          @api.call('sendPhoto', chat_id: user.telegram_id, photo: "https://www.dropbox.com/s/kj2oigmjka6ti0d/telegram_keyboard.jpg?dl=0", reply_markup: nil, parse_mode: 'Markdown')

        when '/cuenta_banco'
          send_message(I18n.t('start.bank_account_text'), nil, 'Markdown')
          send_message(I18n.t('start.bank_account_iban'), nil, 'Markdown')
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