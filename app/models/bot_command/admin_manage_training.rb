module BotCommand
  class AdminManageTraining < Base

    def should_start?
      [
        '/crear_entreno',
        '/editar_entreno',
        '/ver_entrenos',
        '/borrar_entreno'
      ].include?(text)
    end

    def should_step?
      steps = [
                'create_training/date',
                'create_training/hour',
                'create_training/level',
                'create_training/gender',
                'create_training/boat',
                'list_trainings',
                'delete_training',
                'edit_training',
                'edit_training/attributes',
                'edit_training/date',
                'edit_training/hour',
                'edit_training/level',
                'edit_training/gender',
                'edit_training/boat'
              ]

      current_step = user.bot_command_data['step']
      if current_step && steps.include?(current_step)
        true
      else
        user.reset_next_bot_command
        false
      end
    end

    def start
      return send_message(I18n.t('start.wait_activation')) unless user.enabled?
      case text
      when '/crear_entreno'
        user.set_next_step('create_training/date')
        send_message(I18n.t('manage_trainings.insert.date'), set_markup(generate_dates))

      when '/ver_entrenos'
        user.set_next_step('list_trainings')
        set_trainings
        if @trainings.present?
          send_message(I18n.t('manage_trainings.select_trainings.show'), set_markup(@trainings))
        else
          send_message(I18n.t('manage_trainings.not_created_trainings'))
        end

      when '/borrar_entreno'
        user.set_next_step('delete_training')
        set_trainings
        if @trainings.present?
          send_message(I18n.t('manage_trainings.select_trainings.delete'), set_markup(@trainings))
        else
          send_message(I18n.t('manage_trainings.not_created_trainings'))
        end

      when '/editar_entreno'
        user.set_next_step('edit_training')
        set_trainings
        if @trainings.present?
          send_message(I18n.t('manage_trainings.select_trainings.edit'), set_markup(@trainings))
        else
          send_message(I18n.t('manage_trainings.not_created_trainings'))
        end
      end
    end

    def trigger_step
      case user.next_step
      when 'create_training/date'
        user.set_temporary_data('date_tmp', text)
        user.set_next_step('create_training/hour')
        hours = [ "18:00", "18:30"], [ "19:00", "19:30"], ["20:00", "20:30"]
        send_message(I18n.t('manage_trainings.insert.hour'), set_markup(hours))
        
      when 'create_training/hour'
        user.set_next_step('create_training/level')
        if text =~ /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/
          hour = text
          date = user.get_temporary_data('date_tmp')
          user.set_temporary_data('full_date_tmp', DateTime.parse("#{hour} #{date}") )
          send_message(I18n.t('manage_trainings.insert.level'), set_markup(LEVELS))
        else
          send_message(I18n.t('manage_trainings.not_valid_format.hour'))
          user.reset_step
          send_message(I18n.t('start.start'), set_remove_kb)
        end
        
      when 'create_training/level'
        if user.get_temporary_data('full_date_tmp').present?
          user.set_next_step('create_training/gender')
          if LEVELS.flatten.include?(text)
            user.set_temporary_data('level_tmp', text)
            send_message(I18n.t('manage_trainings.insert.gender'), set_markup(GENDERS))
          else
            send_message(I18n.t('manage_trainings.not_valid_format.level'))
            user.reset_step
            send_message(I18n.t('start.start'), set_remove_kb)
          end
        end

      when 'create_training/gender'
        if user.get_temporary_data('full_date_tmp').present? && user.get_temporary_data('level_tmp').present?
          user.set_next_step('create_training/boat')
          if GENDERS.flatten.include?(text)
            user.set_temporary_data('gender_tmp', text)
            send_message(I18n.t('manage_trainings.insert.boat'), set_markup(BOATS))
          else
            send_message(I18n.t('manage_trainings.not_valid_format.gender'))
            user.reset_step
            send_message(I18n.t('start.start'), set_remove_kb)
          end
        end

      when 'create_training/boat'
        user.reset_step
        date = user.get_temporary_data('full_date_tmp')
        level = user.get_temporary_data('level_tmp')
        gender = user.get_temporary_data('gender_tmp')
        if date.present? && level.present? && gender.present?
          if BOATS.flatten.include?(text)
            boat = text
            formatted_date = I18n.l((date).to_time, format: :complete)
            title = set_title(formatted_date, level, gender, boat)
            new_training = user.trainings.build(date: date, gender: gender, level: level, title: title, boat: boat, user_id: user.id)
            new_training.save
            user.reset_next_bot_command
            send_message(I18n.t('manage_trainings.created', title: title), "", 'Markdown')
            send_training_to_all_users(new_training)
          else
            send_message(I18n.t('manage_trainings.not_valid_format.boat'))
            user.reset_next_step
          end
          send_message(I18n.t('start.start'), set_remove_kb)
        end

      when 'list_trainings'
        set_training(text)
        user.reset_step
        if @training.present?
          send_message(I18n.t('manage_trainings.rowers_list'))
          rowers = @training.users
          if rowers.size.zero?
            send_message(I18n.t('manage_trainings.nobody_joined'))
          else
            rowers_text = []
            rowers.each_with_index do |rower, index|
              name = "@#{rower.username}" || "#{rower.first_name} #{rower.last_name}"
              rowers_text << "#{index + 1}.- #{name}"
            end
            send_message(rowers_text.map(&:inspect).join("\n").tr('\"', ''))
          end
          send_message(I18n.t('start.start'), set_remove_kb)
        end

      when 'delete_training'
        set_training(text)
        user.reset_next_bot_command
        if @training.present?
          if @training.destroy
            message = I18n.t('manage_trainings.canceled', title: @training.title)
            send_message(message, nil, 'Markdown')
            send_message_to_rowers(@training, message) if @training.users
          else
            send_message(I18n.t('manage_trainings.not_deleted'))
          end
        else
          send_message(I18n.t('manage_trainings.not_found'))
        end
        send_message(I18n.t('start.start'), set_remove_kb)

      when 'edit_training'
        set_training(text)
        user.reset_step
        if @training.present?
          user.set_temporary_data('training_tmp', @training.id)
          user.set_next_step('edit_training/attributes')
          attributes = [["Fecha", "Hora"], ["Nivel", "Género"], ["Embarcación", "Cancelar"]]
          send_message(I18n.t('manage_trainings.select_edit_data'), set_markup(attributes))
        end

      when 'edit_training/attributes'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_step
        if training.present?
          case text
          when "Fecha"
            user.set_next_step('edit_training/date')
            dates = generate_dates
            send_message(I18n.t('manage_trainings.insert_new.date'), set_markup(dates))
          when "Hora"
            user.set_next_step('edit_training/hour')
            hours = [ "18:00", "18:30"], [ "19:00", "19:30"], ["20:00", "20:30"]
            send_message(I18n.t('manage_trainings.insert_new.hour'), set_markup(hours))
          when "Nivel"
            user.set_next_step('edit_training/level')
            send_message(I18n.t('manage_trainings.insert_new.level'), set_markup(LEVELS))
          when "Género"
            user.set_next_step('edit_training/gender')
            send_message(I18n.t('manage_trainings.insert_new.gender'), set_markup(GENDERS))
          when "Embarcación"
            user.set_next_step('edit_training/boat')
            send_message(I18n.t('manage_trainings.insert_new.boat'), set_markup(BOATS))
          when "Cancelar"
            user.reset_next_bot_command
            send_message(I18n.t('start.start'), set_remove_kb)
          end
        end

      when 'edit_training/date'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          new_date = text.split(",").last.strip.to_datetime rescue nil
          if new_date
            training.date = training.date.change(year: new_date.year, month: new_date.month, day: new_date.day)
            formatted_date = I18n.l((training.date).to_time, format: :complete)
            training.title = set_title(formatted_date, training.level, training.gender, training.boat)
            if training.save
              send_message(I18n.t('manage_trainings.updated', title: training.title), nil, 'Markdown')
              send_training_to_all_users(training, 'date')
            else
              send_message(I18n.t('manage_trainings.not_modified.date'))
            end
          else
            send_message(I18n.t('manage_trainings.not_valid_format.date'))
          end
        else
          send_message(I18n.t('manage_trainings.not_found'))
        end
        send_message(I18n.t('start.start'), set_remove_kb)

      when 'edit_training/hour'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          if text =~ /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/
            training.date = training.date.change(hour: text.split(':').first, min: text.split(':').last)
            formatted_date = I18n.l((training.date).to_time, format: :complete)
            training.title = set_title(formatted_date, training.level, training.gender, training.boat)
            if training.save
              send_message(I18n.t('manage_trainings.updated', title: training.title), nil, 'Markdown')
              send_training_to_all_users(training, 'hour')
            else
              send_message(I18n.t('manage_trainings.not_modified.hour'))
            end
          else
            send_message(I18n.t('manage_trainings.not_valid_format.hour'))
          end
        else
          send_message(I18n.t('manage_trainings.not_found'))
        end
        send_message(I18n.t('start.start'), set_remove_kb)

      when 'edit_training/level'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          if LEVELS.flatten.include?(text)
            training.level = text
            formatted_date = I18n.l((training.date).to_time, format: :complete)
            training.title = set_title(formatted_date, training.level, training.gender, training.boat)
            if training.save
              send_message(I18n.t('manage_trainings.updated', title: training.title), nil, 'Markdown')
              send_training_to_all_users(training, 'level')
            else
              send_message(I18n.t('manage_trainings.not_modified.level'))
            end
          else
            send_message(I18n.t('manage_trainings.not_valid_format.level'))
          end
        else
          send_message(I18n.t('manage_trainings.not_found'))
        end
        send_message(I18n.t('start.start'), set_remove_kb)

      when 'edit_training/gender'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          if GENDERS.flatten.include?(text)
            training.gender = text
            formatted_date = I18n.l((training.date).to_time, format: :complete)
            training.title = set_title(formatted_date, training.level, text, training.boat)
            if training.save
              send_message(I18n.t('manage_trainings.updated', title: training.title), nil, 'Markdown')
              send_training_to_all_users(training, 'gender')
            else
              send_message(I18n.t('manage_trainings.not_modified.gender'))
            end

          else
            send_message(I18n.t('manage_trainings.not_valid_format.gender'))
          end
        else
          send_message(I18n.t('manage_trainings.not_found'))
        end
        send_message(I18n.t('start.start'), set_remove_kb)

      when 'edit_training/boat'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          if BOATS.flatten.include?(text)
            training.boat = text
            formatted_date = I18n.l((training.date).to_time, format: :complete)
            training.title = set_title(formatted_date, training.level, training.gender, text)
            if training.save
              send_message(I18n.t('manage_trainings.updated', title: training.title), nil, 'Markdown')
              send_training_to_all_users(training, 'boat')
            else
              send_message(I18n.t('manage_trainings.not_modified.boat'))
            end

          else
            send_message(I18n.t('manage_trainings.not_valid_format.boat'))
          end
        else
          send_message(I18n.t('manage_trainings.not_found'))
        end
        send_message(I18n.t('start.start'), set_remove_kb)

      end

    end

    def command_data(data)
      user.bot_command_data[data]
    end

    def generate_dates
      dates = []
      (0..6).each{|i| dates << I18n.l((Date.today + i.day).to_time, format: :long)}
      dates
    end

    def set_trainings
      @trainings = Training.where(user_id: user.id).joinable.sort_by(&:date).map{|training| "#{training.title} - \[#{training.users.size.to_s}/#{training.capacity}\]"}
    end

    def set_training(text)
      @training = Training.find_by(title: text.split(" - ").first)
    end

    def send_training_to_all_users(training, attribute=nil)
      admin = training.user
      if attribute
        markup = nil
        text = I18n.t('manage_trainings.updated_by', text: set_attribute_text(attribute), title: training.title, admin_username: admin.username)
      else
        text = I18n.t('manage_trainings.created_by', title: training.title, admin_username: admin.username)

        kb = [
          [Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Me apunto', callback_data: training.id),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: 'No puedo', callback_data: false)]
        ]
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
      end
      telegram_ids = filter_users_ids(training) - [admin.telegram_id]
      telegram_ids.each do |telegram_id|
        unless attribute
          rower = User.find_by(telegram_id: telegram_id)
          rower.set_temporary_data('training_tmp', training.id)
          rower.set_next_bot_command('BotCommand::UserManageTraining')
          rower.set_next_step('join_training/notice')
        end
        @api.call('sendMessage', chat_id: telegram_id, text: text, reply_markup: markup, parse_mode: 'Markdown')
      end
    end

    def send_message_to_rowers(training, message)
      rowers_telegram_ids = training.users.enabled.pluck(:telegram_id) - [training.user.telegram_id]
      rowers_telegram_ids.each do |telegram_id|
        @api.call('sendMessage', chat_id: telegram_id, text: message, reply_markup: nil, parse_mode: 'Markdown')
      end
    end

    def set_title(date, level, gender, boat)
      "#{date} > #{level} #{gender} #{boat}"
    end

    def set_attribute_text(attribute)
      case attribute
      when "date"
        "La fecha"
      when "hour"
        "La hora"
      when "gender"
        "El género"
      when "level"
        "El nivel"
      when "boat"
        "La embarcación"
      end
    end

    def filter_users_ids(training)
      User.enabled.where(level: training.level, gender: user_gender_by_training(training)).pluck(:telegram_id)
    end

    def user_gender_by_training(training)
      case training.gender
      when "Masculino"
        "male"
      when "Femenino"
        "female"
      when "Mixto"
        ["male", "female"]
      end
    end
  end
end



