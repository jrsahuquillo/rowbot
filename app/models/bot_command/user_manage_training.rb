module BotCommand
  class UserManageTraining < Base
    def should_start?
      false
    end

    def should_step?
      steps = [
        'join_training',
        'join_training/notice',
        'exit_training',
        'list_my_trainings'
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
      if user.enabled?
        case user.next_step
        when 'join_training'
          user.reset_next_bot_command
          training = Training.find_by(title: text.split(' - ').first)
          if training.present?
            user_training = UserTraining.new(user_id: user.id, training_id: training.id)
            if user_training.save
              send_message(I18n.t('manage_trainings.join.joined', title: training.title), nil, 'Markdown')
            elsif user_training.errors.full_messages == ["User has already been taken"]
              send_message(I18n.t('manage_trainings.join.already'))
            else
              send_message(I18n.t('manage_trainings.join.error'))
            end
          else
            send_message(I18n.t('manage_trainings.not_found'))
          end

        when 'join_training/notice'
          if data.present?
            training_id = data.to_i
            training = Training.find(training_id)
            user_training = UserTraining.new(user_id: user.id, training_id: training_id)
            if user_training.save
              send_message(I18n.t('manage_trainings.join.joined', title: training.title), nil, 'Markdown')
            elsif user_training.errors.full_messages == ["User has already been taken"]
              send_message(I18n.t('manage_trainings.join.already'))
            else
              send_message(I18n.t('manage_trainings.join.error'))
            end
          else
            send_message(I18n.t('manage_trainings.join.dismiss'))
          end

        when 'exit_training'
          user.reset_next_bot_command
          training = user.trainings.find_by(title: text.split(' - ').first)
          if training.present?
            user_training = UserTraining.find_by(user_id: user.id, training_id: training.id)
            if user_training.destroy
              send_message(I18n.t('manage_trainings.exit.left', title: training.title), nil, 'Markdown')
            else
              send_message(I18n.t('manage_trainings.exit.error'))
            end
          else
            send_message(I18n.t('manage_trainings.not_found'))
          end

        when 'list_my_trainings'
          training = Training.find_by(title: text.split(" - ").first[3..-1])
          user.reset_step
          if training.present?
            send_message(I18n.t('manage_trainings.rowers_list'))
            rowers = training.users
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
          end
        end
      else
        send_message(I18n.t('start.wait_activation'))
      end

      send_message(I18n.t('start.start'), set_remove_kb)
      user.reset_next_bot_command
    end
  end
end