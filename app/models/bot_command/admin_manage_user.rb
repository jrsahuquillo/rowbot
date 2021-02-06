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
                'set_users_role',
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
          user.set_temporary_data('rower_id_tmp', rower.id)
          user.set_next_step('set_users_level')
          rower_text = rower.gender == "female" ? "de la remera" : "del remero"
          send_message("Indica el nivel #{rower_text}", set_markup(LEVELS))
        else
          send_message("El usuario no ha sido localizado")
          send_message('/start', set_remove_kb)
        end

      when 'set_users_level'
        rower_id = user.get_temporary_data('rower_id_tmp')
        rower = User.find(rower_id)
        if rower.present?
          if LEVELS.flatten.include?(text)
            user.set_temporary_data('rower_level_tmp', text)
            user.set_next_step('set_users_role')
            send_message("¿El remero es también entrenador? (Si lo activas como entrenador, podrá gestionar entrenamientos)", set_markup(ROLES))
          else
            send_message("Formato de nivel no válido")
            user.reset_step
            send_message('/start', set_remove_kb)
          end
        else
          send_message("El usuario no ha sido localizado")
          send_message('/start', set_remove_kb)
        end

      when 'set_users_role'
        rower_id = user.get_temporary_data('rower_id_tmp')
        rower = User.find(rower_id)
        if rower.present?
          if ROLES.flatten.include?(text)
            role = parse_role(text)
            level = user.get_temporary_data('rower_level_tmp')
            enabled_status = user.get_temporary_data('rower_enabled_tmp')
            rower.update(enabled: true, role: role, level: level)
            send_message("✅ @#{rower.username} ha sido activado y actualizado con el nivel #{rower.level} y el rol de #{text}.")
            send_state_message(rower, 'enable')
          else
            send_message("Formato de rol no válido")
            user.reset_step
          end
          rower.reset_next_bot_command
          user.reset_next_bot_command
        else
          send_message("El usuario no ha sido localizado")
        end
        send_message('/start', set_remove_kb)

      when 'disable_users'
        rower = User.find_by(username: text.split(' ').first)
        user.reset_step
        if rower.present?
          rower.update(enabled: false, level: nil, role: nil)
          send_message("🚫 @#{rower.username} ha sido desactivado")
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
        message = "✅ @#{user.username} ha activado tu cuenta con el nivel *#{rower.level}* como *#{role_text(rower)}*.\nUsa /start para ver las opciones"
        @api.call('sendMessage', chat_id: rower.telegram_id, text: message, reply_markup: nil, parse_mode: 'Markdown')
      end
      if state == 'disable'
        message = "🚫 @#{user.username} ha desactivado tu cuenta. Si ha sido un error, escríbele por privado"
        @api.call('sendMessage', chat_id: rower.telegram_id, text: message, reply_markup: nil, parse_mode: 'Markdown')
      end
    end

    def role_text(user)
      case user.role
      when 'trainer'
        case user.gender
        when 'male'
          return "Entrenador"
        when 'female'
          return "Entrenadora"
        end
      when 'rower'
        case user.gender
        when 'male'
          return "Remero"
        when 'female'
          return "Remera"
        end
      end
    end

    def parse_role(text)
      case text
      when "Entrenador/a"
        return "trainer"
      when "Remero/a"
        return "rower"
      end
    end

  end
end
