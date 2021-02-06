Rails.application.routes.draw do
  post "/telegram_#{Rails.application.credentials.send(Rails.env).dig(:telegram_token)}" => 'webhooks#callback'
end
