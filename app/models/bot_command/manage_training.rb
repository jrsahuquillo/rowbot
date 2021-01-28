module BotCommand
  class ManageTraining < Base
    def should_start?
      text =~ /\A\/administrar_entrenamientos/ ||
      text =~ /\A\/nuevo_entrenamiento/ ||
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
                'list_trainings'
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
        actions = ['/nuevo_entrenamiento', '/editar_entrenamiento'], ['/ver_entrenamientos', '/borrar_entrenamiento']
        send_message('Administrar entrenamientos:', set_markup(actions))

      when '/nuevo_entrenamiento'
        user.set_next_step('create_training/date')
        dates = generate_dates
        send_message('Introduce día del entrenamiento:', set_markup(dates))

      when '/ver_entrenamientos'
        user.set_next_step('list_trainings')
        trainings = Training.all.sort_by(&:date).map{|training| "\[#{training.users.size.to_s}/8\] - #{training.title}"}
        send_message('Selecciona qué entrenamiento quieres ver:', set_markup(trainings))
      # when '/editar_entrenamiento'
      # when '/borrar_entrenamientos'
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
          # user.reset_next_bot_command
          markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(one_time_keyboard: true, resize_keyboard: true)
          send_message("Entrenamiento - *#{level} - #{gender} - #{date}* creado", markup, 'Markdown')
          send_message('/start')
        end

      when 'list_trainings'
        training = Training.find_by(title: text.split(" - ").last)
        user.reset_step
        if training.present?
          send_message('Listado de remeras/os de este entrenamiento:', set_markup(genders))
          rowers = training.users
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
  end
end



