Rails.application.routes.draw do
  post "/telegram_#{Rails.application.secrets.dig(:telegram_token)}" => 'webhooks#callback'
  get "/status", to: 'webhooks#main'

  get '*path', to: 'application#redirect_user', via: :all
end
