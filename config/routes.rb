Rails.application.routes.draw do
  post "/telegram_#{Rails.application.secrets.dig(:telegram_token)}" => 'webhooks#callback'
end
