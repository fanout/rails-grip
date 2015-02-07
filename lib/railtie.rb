#    railtie.rb
#    ~~~~~~~~~
#    This module implements the Railtie class.
#    :authors: Konstantin Bokarius.
#    :copyright: (c) 2015 by Fanout, Inc.
#    :license: MIT, see LICENSE for more details.

class Railtie < Rails::Railtie
  initializer "rails_grip.configure_rails_initialization" do
    Rails.application.middleware.use GripMiddleware
  end
end
