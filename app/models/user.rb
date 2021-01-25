class User < ApplicationRecord
  validates_uniqueness_of :telegram_id

  def set_next_bot_command(command)
    self.bot_command_data['command'] = command
    save
  end

  def get_next_bot_command
    bot_command_data['command']
  end

  def reset_next_bot_command
    self.bot_command_data = {}
    save
  end

  def set_next_step(step)
    self.bot_command_data['step'] = step
  end

  def reset_step
    self.bot_command_data['step'] = nil
    self.save
  end

  def trigger_bot_step(message)
    if bot_command_data['step'] == 'gender' && ['Remero', 'Remera'].include?(message)
      self.gender = 'male' if message == 'Remero'
      self.gender = 'female' if message == 'Remera'
      self.bot_command_data['step'] = 'welcome'
      self.save
    end
  end
end
