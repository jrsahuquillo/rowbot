module BotCommand
  class ManageTraining < Base

    def should_start?
      text =~ /\A\/administrar_entrenamientos/ ||
      text =~ /\A\/crear_entrenamiento/ ||
      text =~ /\A\/editar_entrenamiento/ ||
      text =~ /\A\/ver_entrenamientos/ ||
      text =~ /\A\/borrar_entrenamiento/
    end

    def should_step?
      steps = [
                'manage_trainings',
                'create_training/date',
                'create_training/hour',
                'create_training/level',
                'create_training/gender',
                'list_trainings',
                'delete_training',
                'edit_training',
                'edit_training/attributes',
                'edit_training/date'
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
      case text
      when '/administrar_entrenamientos'
        user.set_next_step('manage_trainings')
        actions = ['/crear_entrenamiento', '/editar_entrenamiento'], ['/ver_entrenamientos', '/borrar_entrenamiento']
        send_message('Administrar entrenamientos:', set_markup(actions))

      when '/crear_entrenamiento'
        user.set_next_step('create_training/date')
        dates = generate_dates
        send_message('Introduce día del entrenamiento:', set_markup(dates))

      when '/ver_entrenamientos'
        user.set_next_step('list_trainings')
        set_trainings
        send_message('Selecciona qué entrenamiento quieres ver:', set_markup(@trainings))

      when '/borrar_entrenamiento'
        user.set_next_step('delete_training')
        set_trainings
        send_message('Selecciona qué entrenamiento quieres eliminar:', set_markup(@trainings))

      when '/editar_entrenamiento'
        user.set_next_step('edit_training')
        set_trainings
        send_message('Selecciona qué entrenamiento quieres editar:', set_markup(@trainings))
      end
    end

    def trigger_step
      case user.next_step
      when 'create_training/date'
        user.set_temporary_data('date_tmp', text)
        user.set_next_step('create_training/hour')
        hours = [ "18:00", "18:30"], [ "19:00", "19:30"], ["20:00", "20:30"]
        send_message('Introduce la hora del entrenamiento (HH:MM):', set_markup(hours))
        
      when 'create_training/hour'
        user.set_next_step('create_training/level')
        hour = text
        date = user.get_temporary_data('date_tmp')
        user.set_temporary_data('full_date_tmp', DateTime.parse("#{@date} #{hour}") )
        levels = ["Iniciación", "Fitness", "Competición"]
        send_message('Introduce el nivel del entrenamiento:', set_markup(levels))
        
      when 'create_training/level'
        if user.get_temporary_data('full_date_tmp').present?
          user.set_next_step('create_training/gender')
          user.set_temporary_data('level_tmp', text)
          genders = ["Mixto", "Femenino", "Masculino"]
          send_message('Introduce el género del entrenamiento:', set_markup(genders))
        else
          user.reset_step
        end

      when 'create_training/gender'
        user.reset_step
        if user.get_temporary_data('full_date_tmp').present? && user.get_temporary_data('level_tmp').present?
          gender = text
          I18n.locale = :es
          date = I18n.l(user.get_temporary_data('full_date_tmp').to_time, format: :long) 
          level = user.get_temporary_data('level_tmp')
          title = "#{level} #{gender} #{date}"
          new_training = user.trainings.build(date: date, gender: gender, level: level, title: title, user_id: user.id)
          new_training.save
          user.reset_next_bot_command
          # markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(one_time_keyboard: true, resize_keyboard: true)
          send_message("Entrenamiento - *#{title}* creado", nil, 'Markdown')
          send_training_to_all_users(new_training)
          send_message('/start')
        end

      when 'list_trainings'
        set_training(text)
        user.reset_step
        if @training.present?
          send_message('Listado de remeras/os de este entrenamiento:', set_markup(genders))
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
            send_message("Entrenamiento *#{@training.level} #{@training.gender} #{@training.date.strftime("%d-%m-%Y %H:%M")}* eliminado", nil, 'Markdown')
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
            levels = ["Iniciación", "Fitness", "Competición"]
            send_message('Introduce el nuevo nivel del entrenamiento:', set_markup(levels))
          when "Género"
            user.set_next_step('edit_training/gender')
            genders = ["Mixto", "Femenino", "Masculino"]
            send_message('Introduce el nuevo género del entrenamiento:', set_markup(genders))
          end
        end

      when 'edit_training/date'
        training_id = user.get_temporary_data('training_tmp')
        training = Training.find(training_id)
        user.reset_next_bot_command
        if training.present?
          new_date = text.to_datetime rescue nil
          if new_date
            if training.update(date: new_date, title: "#{training.level} #{training.gender} #{text}")
              send_message("Entrenamiento *#{training.level} #{training.gender} #{training.date.strftime("%d-%m-%Y %H:%M")}* actualizado", nil, 'Markdown')
              send_training_to_all_users(training, 'date')
            end
          end
        end
        send_message('/start')

      when 'edit_training/hour'
      when 'edit_training/level'
      when 'edit_training/gender'

      end

    end

    def set_markup(actions)
      Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: actions, one_time_keyboard: true, resize_keyboard: true)
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
      @trainings = Training.all.sort_by(&:date).map{|training| "\[#{training.users.size.to_s}/8\] - #{training.title}"}
    end

    def set_training(text)
      @training = Training.find_by(title: text.split(" - ").last)
    end

    def send_training_to_all_users(training, attribute=nil)
      admin = training.user
      text =
      if attribute
        attribute_text = set_attribute_text(attribute)
        "@#{admin.username} ha actualizado #{attribute_text} del entrenamiento *#{training.title}*."
      else
        "*#{training.title}* ha sido creado por @#{admin.username}. ¿Te apuntas?"
      end
      telegram_ids = User.pluck(:telegram_id)
      telegram_ids.each do |telegram_id|
        @api.call('sendMessage', chat_id: telegram_id, text: text, reply_markup: nil, parse_mode: 'Markdown')
      end
    end

    def set_attribute_text(attribute)
      case attribute
      when "date"
        "la fecha"
      when "hour"
        "la hora"
      when "gender"
        "el género"
      when "level"
        "el nivel"
      end
    end
  end
end



