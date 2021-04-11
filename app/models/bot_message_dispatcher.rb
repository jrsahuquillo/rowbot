class BotMessageDispatcher
  attr_reader :message, :user

  def initialize(message, user)
    @message = message
    @user = user
  end

  def process
    bot_command =
    if message[:callback_query] && message[:callback_query][:data].present?
      user.update_column(:bot_command_data, {"command"=>"BotCommand::UserManageTraining", "step" => "join_training/notice"})
      user.get_next_bot_command.safe_constantize.new(user, message)
    else
      !user.get_next_bot_command || (message['message']['text'] == '/start' rescue nil) ?
      BotCommand::Start.new(user, message) :
      user.get_next_bot_command.safe_constantize.new(user, message)
    end

    if bot_command.should_start?
      bot_command.start
    elsif bot_command.should_step?
      bot_command.trigger_step
    else
      unknown_command
    end
  end
  
  private

  def unknown_command
    BotCommand::Undefined.new(user, message).start
  end
end