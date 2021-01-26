class BotMessageDispatcher
  attr_reader :message, :user

  def initialize(message, user)
    @message = message
    @user = user
  end

  def process
    bot_command = !user.get_next_bot_command || message['message']['text'] == '/start' ?
                                                BotCommand::Start.new(user, message) :
                                                user.get_next_bot_command.safe_constantize.new(user, message)
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