module BotCommand
  class AdminManageTraining < Base

    def should_start?
      [
        '/crear_entrenamiento',
        '/editar_entrenamiento',
        '/ver_entrenamientos',
        '/borrar_entrenamiento'
      ].include?(text)
    end

    def should_step?
      steps = [
                'create_training/date',
                'create_training/hour',
                'create_training/level',
                'create_training/gender',
                'list_trainings',
                'delete_training',
                'edit_training',
                'edit_training/attributes',
                'edit_training/date',
                'edit_training/hour',
                'edit_training/level',
                'edit_training/gender'
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
      return send_message('Espera a que un entrenador active tu cuenta. ⛔️') unless user.enabled?
      case text
      when '/crear_entrenamiento'
        user.set_next_step('create_training/date')
        send_message('🗓 Introduce día del entrenamiento:', set_markup(generate_dates))

      when '/ver_entrenamientos'
        user.set_next_step('list_trainings')
        set_trainings
        if @trainings.present?
          send_message('Selecciona qué entrenamiento quieres ver:', set_markup(@trainings))
        else
          send_message('No hay entrenamientos creados')
        end

      when '/borrar_entrenamiento'
        user.set_next_step('delete_training')
        set_trainings
        if @trainings.present?
          send_message('Selecciona qué entrenamiento quieres eliminar:', set_markup(@trainings))
        else
          send_message('No hay entrenamientos creados')
        end

      when '/editar_entrenamiento'
        user.set_next_step('edit_training')
        set_trainings
        if @trainings.present?
          send_message('Selecciona qué entrenamiento quieres editar:', set_markup(@trainings))
        else
          send_message('No hay entrenamientos creados')
        end
      end
    end

    def trigger_step
      case user.next_step
      when 'create_training/date'
        user.set_temporary_data('date_tmp', text)
        user.set_next_step('create_training/hour')
        hours = [ "18:00", "18:30"], [ "19:00", "19:30"], ["20:00", "20:30"]
        send_message('🕑 Introduce la hora del entrenamiento (HH:MM):', set_markup(hours))
        
      when 'create_training/hour'
        user.set_next_step('create_training/level')
        if text =~ /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/
          hour = text
          date = user.get_temporary_data('date_tmp')
          user.set_temporary_data('full_date_tmp', DateTime.parse("#{@date} #{hour}") )
          send_message('💪🏻 Introduce el nivel del entrenamiento:', set_markup(LEVELS))
        else
          send_message("Formato de hora no válida")
          user.reset_step
          send_message('/start')
        end
        
      when 'create_training/level'
        if user.get_temporary_data('full_date_tmp').present?
          user.set_next_step('create_training/gender')
          if LEVELS.flatten.include?(text)
            user.set_temporary_data('level_tmp', text)
            send_message('♀︎♂︎ Introduce el género del entrenamiento:', set_markup(GENDERS))
          else
            send_message("Formato de nivel no válido")
            user.reset_step
            send_message('/start')
          end
        end

      when 'create_training/gender'
        user.reset_step
        if user.get_temporary_data('full_date_tmp').present? && user.get_temporary_data('level_tmp').present?
          if GENDERS.flatten.include?(text)
            gender = text
            I18n.locale = :es
            date = I18n.l(user.get_temporary_data('full_date_tmp').to_time, format: :complete) 
            level = user.get_temporary_data('level_tmp')
            title = "#{date} > #{level} #{gender}"
            new_training = user.trainings.build(date: date, gender: gender, level: level, title: title, user_id: user.id)
            new_training.save
            user.reset_next_bot_command
            send_message("Entrenamiento - *#{title}* creado", nil, 'Markdown')
            send_training_to_all_users(new_training)
          else
            send_message("Formato de género no válido")
            user.reset_next_step
          end
          send_message('/start')
        end

      when 'list_trainings'
        set_training(text)
        user.reset_step
        if @training.present?
          send_message('Listado de remeras/os de este entrenamiento:')
          rowers = @training.users
          if rowers.size.zero?
            send_message('Todavía no hay nadie apuntado a este entrenamiento')
          else
            rowers_text = []
            rowers.each_with_index do |rower, index|
              name = "@#{rower.username}" || "#{rower.first_name} #{rower.last_name}"
              rowers_text << "#{index + 1}.- #{name}"
            end
            send_message(rowers_text.map(&:inspect).join("\n").tr('\"', ''))
          end
          send_message('/start')
        end

      when 'delete_training'
        set_training(text)
        user.reset_next_bot_command
        if @training.present?
          if @training.destroy
            message = "❌ El entrenamiento *#{@training.level} #{@training.gender} #{@training.date.strftime("%d/%m/%Y %H:%M")}* ha sido cancelado"
            send_message(message, nil, 'Markdown')
            send_message_to_rowers(@training, message) if @training.users
          else
            send_message("El entrenamiento no se ha podido eliminar")
          end
        else
          send_message("Entrenamiento no encontrado")
        end
        send_message('/start')

      when 'edit_training'
        set_training(text)
        user.reset_step
        if @training.present?
          user.set_temporary_data('training_tmp', @training.id)
          user.set_next_step('edit_training/attributes')
          attributes = [["Fecha", "Hora"], ["Nivel", "Género"]]
          send_message('Selecciona el dato que quieres editar', set_markup(attributes))
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
            send_message('Introduce el nuevo día del entrenamiento:', set_markup(dates))
          when "Hora"
            user.set_next_step('edit_training/hour')
            hours = [ "18:00", "18:30"], [ "19:00", "19:30"], ["20:00", "20:30"]
            send_message('Introduce la nueva hora del entrenamiento:', set_markup(hours))
          when "Nivel"
            user.set_next_step('edit_training/level')
            send_message('Introduce el nuevo nivel del entrenamiento:', set_markup(LEVELS))
          when "Género"
            user.set_next_step('edit_training/gender')
            send_message('Introduce el nuevo género del entrenamiento:', set_markup(GENDERS))
          end
        end

      when 'edit_training/date'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          new_date = text.to_datetime rescue nil
          if new_date
            training.date = training.date.change(year: new_date.year, month: new_date.month, day: new_date.day)
            I18n.locale = :es
            formated_date = I18n.l((training.date).to_time, format: :complete)
            training.title = "#{formated_date} > #{training.level} #{training.gender}"
            if training.save
              send_message("Entrenamiento *#{training.title}* actualizado", nil, 'Markdown')
              send_training_to_all_users(training, 'date')
            else
              send_message("No se pudo modificar la fecha del entrenamiento")
            end
          else
            send_message("Formato de fecha no válido")
          end
        else
          send_message("Entrenamiento no encontrado")
        end
        send_message('/start')

      when 'edit_training/hour'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          if text =~ /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/
            training.date = training.date.change(hour: text.split(':').first, min: text.split(':').last)
            I18n.locale = :es
            formated_date = I18n.l((training.date).to_time, format: :complete)
            training.title = "#{formated_date} > #{training.level} #{training.gender}"
            if training.save
              send_message("Entrenamiento *#{training.title}* actualizado", nil, 'Markdown')
              send_training_to_all_users(training, 'hour')
            else
              send_message("No se pudo modificar la hora del entrenamiento")
            end
          else
            send_message("Formato de hora no válida")
          end
        else
          send_message("Entrenamiento no encontrado")
        end
        send_message('/start')

      when 'edit_training/level'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          if LEVELS.flatten.include?(text)
            training.level = text
            training.title = "#{training.date} > #{text} #{training.gender}"
            if training.save
              send_message("Entrenamiento *#{training.title}* actualizado", nil, 'Markdown')
              send_training_to_all_users(training, 'level')
            else
              send_message("No se pudo modificar el nivel del entrenamiento")
            end
          else
            send_message("Formato de nivel no válido")
          end
        else
          send_message("Entrenamiento no encontrado")
        end
        send_message('/start')

      when 'edit_training/gender'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          if GENDERS.flatten.include?(text)
            training.gender = text
            training.title = "#{training.date} > #{training.level} #{text}"
            if training.save
              send_message("Entrenamiento *#{training.title}* actualizado", nil, 'Markdown')
              send_training_to_all_users(training, 'gender')
            else
              send_message("No se pudo modificar el nivel del entrenamiento")
            end

          else
            send_message("Formato de género no válido")
          end
        else
          send_message("Entrenamiento no encontrado")
        end
        send_message('/start')

      end

    end

    def command_data(data)
      user.bot_command_data[data]
    end

    def generate_dates
      I18n.locale = :es
      dates = []
      (0..6).each{|i| dates << I18n.l((Date.today + i.day).to_time, format: :long)}
      dates
    end

    def set_trainings
      @trainings = Training.all.sort_by(&:date).map{|training| "#{training.title} - \[#{training.users.size.to_s}/8\]"}
    end

    def set_training(text)
      @training = Training.find_by(title: text.split(" - ").first)
    end

    def send_training_to_all_users(training, attribute=nil)
      admin = training.user
      text =
      if attribute
        markup = nil
        attribute_text = set_attribute_text(attribute)
        "⚠️ *#{attribute_text}* del entrenamiento:\n*#{training.title}*\nha sido actualizado por @#{admin.username}."
      else
        actions = ["¡Me apunto!", "No me apunto"]
        markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: actions, one_time_keyboard: true, resize_keyboard: true)
        "✅ El entrenamiento:\n *#{training.title}* ha sido creado por @#{admin.username}.\n ¿Te apuntas?"
      end
      telegram_ids = User.pluck(:telegram_id)
      telegram_ids.each do |telegram_id|
        @api.call('sendMessage', chat_id: telegram_id, text: text, reply_markup: markup, parse_mode: 'Markdown')
      end
    end

    def send_message_to_rowers(training, message)
      rowers_telegram_ids = training.users.pluck(:telegram_id)
      rowers_telegram_ids.each do |telegram_id|
        @api.call('sendMessage', chat_id: telegram_id, text: message, reply_markup: nil, parse_mode: 'Markdown')
      end
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
      end
    end
  end
end



