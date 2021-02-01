class User < ApplicationRecord
  has_many :user_trainings
  has_many :trainings, through: :user_trainings

  validates_uniqueness_of :telegram_id

  scope :enabled, -> { where(enabled: true) }

  def admin?
    self.role == 'admin'
  end

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

  def next_step
    self.bot_command_data['step']
  end

  def set_next_step(step)
    self.bot_command_data['step'] = step
    save
  end

  def reset_step
    self.bot_command_data['step'] = nil
    save
  end

  def trigger_bot_step(message)
    if bot_command_data['step'] == 'gender' && ['Remero', 'Remera'].include?(message)
      self.gender = 'male' if message == 'Remero'
      self.gender = 'female' if message == 'Remera'
      self.bot_command_data['step'] = 'welcome'
      self.save
    end
  end

  def set_temporary_data(key, value)
    self.bot_command_data[key] = value
    self.save
  end

  def get_temporary_data(key)
    self.bot_command_data[key]
  end
end
