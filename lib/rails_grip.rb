require 'pubcontrol'
require 'gripcontrol'

require_relative 'gripmiddleware.rb'

class RailsGrip
  @@pub_config = nil
  @@grip_config = nil

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

  def self.configure(pub_config=nil, grip_config=nil)
    @@pub_config = pub_config;
    @@grip_config = grip_config;
  end

  private

  def self.get_pubcontrol
    if Thread.current['pubcontrol'].nil?
      pub = GripPubControl.new()
      if !@@pub_config.nil?
        pub.apply_config(@@pub_config)
      end
      if !@@grip_config.nil?
        pub.apply_grip_config(@@grip_config)        
      end
      at_exit { pub.finish }
      Thread.current['pubcontrol'] = pub
    end
    return Thread.current['pubcontrol']
  end
end

require_relative 'railtie.rb' if defined? Rails::Railtie
