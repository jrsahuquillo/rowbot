Rails.application.routes.draw do
  post "/telegram_#{Rails.application.credentials.send(Rails.env)[:telegram_token]}" => 'webhooks#callback'
end
