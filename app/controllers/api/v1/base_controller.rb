module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::MimeResponds
    end
  end
end
