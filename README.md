rails-grip
================

Author: Konstantin Bokarius <kon@fanout.io>

A Ruby on Rails GRIP library.

License
-------

rails-grip is offered under the MIT license. See the LICENSE file.

Installation
------------

```sh
gem install rails_grip
```

Add the following lines to your Rails application Gemfile:

```Ruby
gem 'gripcontrol'
gem 'rails_grip'
```

Usage
-----

Set grip_proxies in your application configuration:

```Ruby
module GripApp
  class Application < Rails::Application
    # pushpin and/or fanout.io is used for sending realtime data to clients
    config.grip_proxies = [
        # pushpin
        {
            'control_uri' => 'http://localhost:5561',
            'key' => 'changeme'
        }
        # fanout.io
        #{
        #    'control_uri' => 'https://api.fanout.io/realm/your-realm',
        #    'control_iss' => 'your-realm',
        #    'key' => Base64.decode64('your-realm-key')
        #}
    ]
    ...
```

You can also set any other EPCP servers that aren't necessarily proxies with publish_servers:

```Ruby
module GripApp
  class Application < Rails::Application
```
```
    config.publish_servers = [
        {
            'uri' => 'http://example.com/base-uri',
            'iss' => 'your-iss', 
            'key' => 'your-key'
        }
    ]
    ...
```

Note that in Rails 4 the following should be set for API endpoints in the ApplicationController to avoid CSRF authenticity exceptions:

```Ruby
protect_from_forgery except: :<api_endpoint>
```

Example controller:

```Ruby
class GripController < ApplicationController
  def get
    # if the request didn't come through a GRIP proxy, throw 501
    if !RailsGrip.is_grip_proxied(request)
      render :text => "Not implemented\n", :status => 501
      return
    end

    # subscribe every incoming request to a channel in stream mode
    RailsGrip.set_hold_stream(request, '<channel>')
    render :text => '[stream open]'
  end

  def post
    # publish data to subscribers
    data = request.body.read
    RailsGrip.publish('<channel>', HttpStreamFormat.new(data + "\n"))
    render :text => "Ok\n"
  end
end
```
