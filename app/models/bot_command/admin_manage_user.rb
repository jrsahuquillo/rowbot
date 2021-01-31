module BotCommand
  class AdminManageUser < Base

    def should_start?
      [
        '/administrar_socios',
        '/activar_socios',
        '/desactivar_socios'
      ].include?(text)
    end

    def should_step?
      steps = [
                'enable_users',
                'set_users_level',
                'disable_users'
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
        disabled_rowers = User.where(enabled: false).sort_by(&:created_at).map{|rower| "#{rower.username} (#{rower.first_name} #{rower.last_name})" }
        unleveled_rowers = User.where(level: nil).sort_by(&:created_at).map{|rower| "#{rower.username} (#{rower.first_name} #{rower.last_name})"}
        rowers = (disabled_rowers + unleveled_rowers).uniq
        send_message('Selecciona al socio/a que quieres activar:', set_markup(rowers))

      when '/desactivar_socios'
        user.set_next_step('disable_users')
        enabled_rowers = User.where(enabled: true).sort_by(&:created_at).map{|rower| "#{rower.username} (#{rower.first_name} #{rower.last_name})" }
        send_message('Selecciona al socio/a que quieres desactivar:', set_markup(enabled_rowers))
      end
    end

    def trigger_step
      case user.next_step
      when 'enable_users'
        rower = User.find_by(username: text.split(' ').first)
        user.reset_step
        if rower.present?
          user.set_temporary_data('rower_it_tmp', rower.id)
          user.set_next_step('set_users_level')
          rower.update_column(:enabled, true)
          rower_text = rower.gender == "female" ? "de la remera" : "del remero"
          send_message("Indica el nivel #{rower_text}", set_markup(LEVELS))
        else
          send_message("El usuario no ha sido localizado")
        end
        send_message('/start', set_remove_kb)

      when 'set_users_level'
        rower_id = user.get_temporary_data('rower_it_tmp')
        rower = User.find(rower_id)
        if rower.present?
          if LEVELS.flatten.include?(text)
            rower.save
            rower.update_column(:level, text)
            send_message("✅ @#{rower.username} ha sido activado y actualizado con el nivel #{rower.level}")
            send_state_message(rower, 'enable')
          else
            send_message("Formato de nivel no válido")
            user.reset_step
            send_message('/start', set_remove_kb)
          end
          rower.reset_next_bot_command
          user.reset_next_bot_command
        end
        send_message('/start', set_remove_kb)

      when 'disable_users'
        rower = User.find_by(username: text.split(' ').first)
        user.reset_step
        if rower.present?
          rower.update_column(:enabled, false)
          send_message("@#{rower.username} ha sido desactivado")
          send_state_message(rower, 'disable')
          rower.reset_next_bot_command
          user.reset_next_bot_command
        else
          send_message("El usuario no ha sido localizado")
        end
        send_message('/start', set_remove_kb)

      end
    end

    def send_state_message(rower, state)
      if state == 'enable'
        message = "🟢 @#{user.username} ha activado tu cuenta con el nivel *#{rower.level}*.\nUsa /start para ver las opciones"
        @api.call('sendMessage', chat_id: rower.telegram_id, text: message, reply_markup: nil, parse_mode: 'Markdown')
      end
      if state == 'disable'
        message = "🚫 @#{user.username} ha desactivado tu cuenta. Si ha sido un error, escríbele por privado"
        @api.call('sendMessage', chat_id: rower.telegram_id, text: message, reply_markup: nil, parse_mode: 'Markdown')
      end
    end

  end
end
