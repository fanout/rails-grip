class Railtie < Rails::Railtie
  initializer "rails_grip.configure_rails_initialization" do
    Rails.application.middleware.use GripMiddleware
  end
end
