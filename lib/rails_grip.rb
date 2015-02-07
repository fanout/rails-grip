#    rails_grip.rb
#    ~~~~~~~~~
#    This module implements the RailsGrip class.
#    :authors: Konstantin Bokarius.
#    :copyright: (c) 2015 by Fanout, Inc.
#    :license: MIT, see LICENSE for more details.

require 'pubcontrol'
require 'gripcontrol'

require_relative 'gripmiddleware.rb'

class RailsGrip
  def self.publish(channel, formats, id=nil, prev_id=nil)
    pub = RailsGrip.get_pubcontrol
    pub.publish(channel, Item.new(formats, id, prev_id))
  end

  def self.publish_async(channel, formats, id=nil, prev_id=nil, callback=nil)
    pub = RailsGrip.get_pubcontrol
    pub.publish_async(channel, Item.new(formats, id, prev_id), callback)
  end

  def self.set_hold_longpoll(request, channels, timeout=nil)
    request.env['grip_hold'] = 'response'
    request.env['grip_channels'] = channels
    request.env['grip_timeout'] = timeout
  end

  def self.set_hold_stream(request, channels)
    request.env['grip_hold'] = 'stream'
    request.env['grip_channels'] = channels
  end

  def self.is_grip_proxied(request)
    if request.env.key?('grip_proxied')
      return request.env['grip_proxied']
    end
    return false
  end

  def self.get_wscontext(request)
    if request.env.key?('grip_wscontext')
      return request.env['grip_wscontext']
    end
    return nil
  end

  def self.verify_is_websocket(request)
    if !RailsGrip.get_wscontext(request)
      raise NonWebSocketRequestError
    end
  end

  private

  def self.get_pubcontrol
    if Thread.current['pubcontrol'].nil?
      pub = GripPubControl.new
      if Rails.application.config.respond_to?(:grip_proxies)
        pub.apply_grip_config(Rails.application.config.grip_proxies)
      end
      if Rails.application.config.respond_to?(:publish_servers)
        pub.apply_config(Rails.application.config.publish_servers)
      end
      at_exit { pub.finish }
      Thread.current['pubcontrol'] = pub
    end
    return Thread.current['pubcontrol']
  end
end

require_relative 'railtie.rb' if defined? Rails::Railtie
