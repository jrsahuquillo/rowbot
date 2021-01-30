module BotCommand
  class ManageUser < Base

    def should_start?
      text =~ /\A\/activar_socios/ ||
      text =~ /\A\/desactivar_socios/
    end

    def should_step?
      steps = [
                'enable_users',
                'set_users_level'
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
      when '/activar_socios'
        user.set_next_step('enable_users')
        disabled_users = User.where(enabled: false).sort_by(&:created_at).map{|user| "#{user.username}" }
        unleveled_users = User.where(level: nil).sort_by(&:created_at).map{|user| "#{user.username}"}
        rowers = (disabled_users + unleveled_users).uniq
        send_message('Selecciona al socio/a que quieres activar:', set_markup(rowers))
      when '/desactivar_socios'
        byebug
      end
    end

    def trigger_step
      case user.next_step
      when 'enable_users'
        rower = User.find_by(username: text)
        user.reset_step
        if rower.present?
          user.set_temporary_data('rower_it_tmp', rower.id)
          user.set_next_step('set_users_level')
          rower.update_column(:enabled, true)
          rower_text = rower.gender == "female" ? "de la remera" : "del remero"
          send_message("Indica el nivel #{rower_text}", set_markup(LEVELS))
        end
      when 'set_users_level'
        rower_id = user.get_temporary_data('rower_it_tmp')
        rower = User.find(rower_id)
        if rower.present?
          if LEVELS.flatten.include?(text)
            rower.save
            rower.update_column(:level, text)
            send_message("@#{rower.username} ha sido activado y actualizado con el nivel #{rower.level}")
            send_update_message(rower)
          else
            send_message("Formato de nivel no válido")
            user.reset_step
            send_message('/start')
          end
          rower.reset_next_bot_command
          user.reset_next_bot_command
        end
      end
    end

    def send_update_message(rower)
      message = "@#{user.username} ha activado tu cuenta con el nivel *#{rower.level}*.\nUsa /start para ver las opciones"
      @api.call('sendMessage', chat_id: rower.telegram_id, text: message, reply_markup: nil, parse_mode: 'Markdown')

    end

    def set_markup(actions)
      Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: actions, one_time_keyboard: true, resize_keyboard: true)
    end

  end
end
