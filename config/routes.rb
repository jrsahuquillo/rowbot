Rails.application.routes.draw do
  post '/telegram_37af92585d15fa95ee83a2091f3558e778e75a26' => 'webhooks#callback'
end

# https://api.telegram.org/bot1558863522:AAG_18JKNM5s6CrtcWRKMSsCWy31EgRfkMY/setWebhook?url=https://ebef4be6e9e3.ngrok.io/telegram_37af92585d15fa95ee83a2091f3558e778e75a26