Rails.application.routes.draw do
  post '/telegram_37af92585d15fa95ee83a2091f3558e778e75a26' => 'webhooks#callback'
end
