Rails.application.routes.draw do
  root to: 'webhooks#main'
  post "/telegram_#{Rails.application.secrets.dig(:telegram_token)}" => 'webhooks#callback'
end
