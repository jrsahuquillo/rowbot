module BotCommand
  class UserManageTraining < Base
    def should_start?
      false
    end

    def should_step?
      steps = [
        'join_training'
      ]
      current_step = user.bot_command_data['step']
      if current_step && steps.include?(current_step)
        true
      else
        user.reset_next_bot_command
        false
      end
    end

    def start; end

    def trigger_step
      case user.next_step
      when 'join_training'
        user.reset_next_bot_command
        training = Training.find_by(title: text.split(' - ').first)
        if training.present?
          if user.trainings.include?(training)
            send_message("Ya te habías unido a este entrenamiento. 🤡")
          else
            user_training = UserTraining.new(user_id: user.id, training_id: training.id)
            if user_training.save
              send_message("🚣🏻 Te has unido a *#{training.title}*", nil, parse_mode: 'Markdown')
            else
              send_message_to_rowers('Ha habido algún error al tratar de unirte al entrenamiento. 🤷🏻‍♂️')
            end
          end
        else
          send_message_to_rowers('No se ha encontrado el entrenamiento. 🤷🏻‍♂️')
        end
        send_message('/start')


      when 'cancel_training'
      end
    end
  end
end